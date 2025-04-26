#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5; // 时间周期
input int InpBaseMagicNumber = 34288;           // 基础魔术号
input double InpLotSize = 0.03;                 // 交易手数
input int InpEMA = 20;                          // EMA
input int InpFluctuatePoints = 200;             // 波动点数
input int InpMaxMultiplier = 16;                // 最大手数倍数限制

class CVolatilityStrategy : public CStrategy
{
private:
    CTools *m_Tools;
    CMA *m_EMA;
    double m_LastLotSize;        // 记录上一次开仓手数
    bool m_TodayTradingFinished; // 标记今日交易是否已完成
    datetime m_LastTradeDay;     // 记录上一次交易的日期

public:
    CVolatilityStrategy(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, InpEMA, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_LastLotSize = InpLotSize;
        m_TodayTradingFinished = false;
        m_LastTradeDay = 0;
    }

    bool Initialize() override
    {
        if (!m_EMA.Initialize())
            return false;
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    SignalType TradeSignal() override
    {
        double currentClosePrice = iClose(m_Symbol, m_Timeframe, 1);
        double ema = m_EMA.GetValue(1);

        if (currentClosePrice > ema)
            return BuySignal;
        else if (currentClosePrice < ema)
            return SellSignal;

        return NoSignal;
    }

    bool TimeSession(int aStartHour, int aStartMinute, int aStopHour, int aStopMinute, datetime aTimeCur)
    {
        //--- session start time
        int StartTime = 3600 * aStartHour + 60 * aStartMinute;
        //--- session end time
        int StopTime = 3600 * aStopHour + 60 * aStopMinute;
        //--- current time in seconds since the day start
        aTimeCur = aTimeCur % 86400;
        if (StopTime < StartTime)
        {
            //--- going past midnight
            if (aTimeCur >= StartTime || aTimeCur < StopTime)
            {
                return (true);
            }
        }
        else
        {
            //--- within one day
            if (aTimeCur >= StartTime && aTimeCur < StopTime)
            {
                return (true);
            }
        }
        return (false);
    }

    // 检查是否有盈利的交易
    bool HasProfitableTradeToday()
    {
        datetime today = iTime(m_Symbol, PERIOD_D1, 0);
        double totalProfit = 0.0;

        if (HistorySelect(today, TimeCurrent()))
        {
            int total = HistoryDealsTotal();
            for (int i = 0; i < total; i++)
            {
                ulong ticket = HistoryDealGetTicket(i);
                if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == m_MagicNumber)
                {
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    totalProfit += profit;
                }
            }
        }

        return totalProfit > 0;
    }

    // 检查当前持仓是否有盈利
    bool HasOpenPositionProfit()
    {
        double totalProfit = 0.0;
        int total = PositionsTotal();

        for (int i = 0; i < total; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionGetInteger(POSITION_MAGIC) == m_MagicNumber)
            {
                totalProfit += PositionGetDouble(POSITION_PROFIT);
            }
        }

        return totalProfit > 0;
    }

    // 重置每日交易状态
    void ResetDailyTrading()
    {
        datetime today = iTime(m_Symbol, PERIOD_D1, 0);
        if (m_LastTradeDay != today)
        {
            m_LastTradeDay = today;
            m_TodayTradingFinished = false;
            m_LastLotSize = InpLotSize; // 重置为首单手数
        }
    }

    void OnTick() override
    {
        // 检查是否是新的交易日
        ResetDailyTrading();

        // 如果今日交易已完成，则不再交易
        if (m_TodayTradingFinished)
            return;

        // 如果已经有盈利的交易，则今日交易完成
        if (HasProfitableTradeToday())
        {
            m_TodayTradingFinished = true;
            return;
        }

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        // 13:30-20:00 才进行交易
        if (!TimeSession(13, 30, 20, 0, TimeCurrent()))
            return;

        // 检查是否有持仓
        int positionCount = m_Tools.GetPositionCount(m_MagicNumber);
        if (positionCount > 0)
        {
            // 如果有持仓且盈利，则今日交易完成
            if (HasOpenPositionProfit())
            {
                m_TodayTradingFinished = true;
            }
            return;
        }

        SignalType signal = TradeSignal();
        if (signal == NoSignal)
            return;

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        // 计算手数，不超过最大倍数限制
        double lotSize = m_LastLotSize;
        if (!HasProfitableTradeToday() && m_LastLotSize < InpLotSize * InpMaxMultiplier)
        {
            lotSize = m_LastLotSize * 2;
        }

        // 确保手数不超过账户允许的最大值
        double maxLot = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MAX);
        lotSize = MathMin(lotSize, maxLot);

        if (signal == BuySignal)
        {
            double sl = ask - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = ask + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            if (m_Trade.Buy(lotSize, m_Symbol, ask, sl, tp, "Buy Entry"))
            {
                m_LastLotSize = lotSize; // 记录本次开仓手数
            }
        }
        else if (signal == SellSignal)
        {
            double sl = bid + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = bid - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            if (m_Trade.Sell(lotSize, m_Symbol, bid, sl, tp, "Sell Entry"))
            {
                m_LastLotSize = lotSize; // 记录本次开仓手数
            }
        }
    }
};

CVolatilityStrategy *g_Strategy;

int OnInit()
{
    g_Strategy = new CVolatilityStrategy(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy");
        return -1;
    }
    return 0;
}

void OnDeinit(const int reason)
{
    delete g_Strategy;
}

void OnTick()
{
    g_Strategy.OnTick();
}