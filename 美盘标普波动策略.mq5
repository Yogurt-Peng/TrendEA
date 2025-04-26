#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5; // 时间周期
input int InpBaseMagicNumber = 34288;           // 基础魔术号
input double InpLotSize = 0.03;                 // 初始交易手数
input int InpEMA = 20;                          // EMA
input int InpFluctuatePoints = 200;             // 波动点数
input int InpMaxMultiplier = 64;                // 最大手数倍数限制

class CVolatilityStrategy : public CStrategy
{
private:
    CTools *m_Tools;
    CMA *m_EMA;
    double m_CurrentLotSize;       // 当前交易手数
    bool m_TodayTradingFinished;   // 标记今日交易是否已完成
    datetime m_LastTradeDay;       // 记录上一次交易的日期
    SignalType m_FirstTradeSignal; // 记录今日首次交易信号
    bool m_FirstTradeExecuted;     // 标记今日首次交易是否已执行
    bool m_WaitingForNewSignal;    // 标记是否在等待新信号

public:
    CVolatilityStrategy(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, InpEMA, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_CurrentLotSize = InpLotSize;
        m_TodayTradingFinished = false;
        m_LastTradeDay = 0;
        m_FirstTradeSignal = NoSignal;
        m_FirstTradeExecuted = false;
        m_WaitingForNewSignal = false;
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
        // 原有时间判断逻辑保持不变
        int StartTime = 3600 * aStartHour + 60 * aStartMinute;
        int StopTime = 3600 * aStopHour + 60 * aStopMinute;
        aTimeCur = aTimeCur % 86400;
        if (StopTime < StartTime)
        {
            if (aTimeCur >= StartTime || aTimeCur < StopTime)
                return true;
        }
        else
        {
            if (aTimeCur >= StartTime && aTimeCur < StopTime)
                return true;
        }
        return false;
    }

    // 检查今日是否有盈利的交易
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

    // 检查是否有止损的交易
    bool HasStoppedOutTradeToday(SignalType &lastSignal)
    {
        datetime today = iTime(m_Symbol, PERIOD_D1, 0);

        if (HistorySelect(today, TimeCurrent()))
        {
            int total = HistoryDealsTotal();
            for (int i = total - 1; i >= 0; i--) // 从最新交易开始检查
            {
                ulong ticket = HistoryDealGetTicket(i);
                if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == m_MagicNumber)
                {
                    long reason = HistoryDealGetInteger(ticket, DEAL_REASON);
                    if (reason == DEAL_REASON_SL) // 止损平仓
                    {
                        long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
                        if (type == DEAL_TYPE_BUY)
                            lastSignal = BuySignal;
                        else if (type == DEAL_TYPE_SELL)
                            lastSignal = SellSignal;
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // 重置每日交易状态
    void ResetDailyTrading()
    {
        datetime today = iTime(m_Symbol, PERIOD_D1, 0);
        if (m_LastTradeDay != today)
        {
            m_LastTradeDay = today;
            m_TodayTradingFinished = false;
            m_CurrentLotSize = InpLotSize;
            m_FirstTradeSignal = NoSignal;
            m_FirstTradeExecuted = false;
            m_WaitingForNewSignal = false;
        }
    }

    // 执行交易
    void ExecuteTrade(SignalType signal)
    {
        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        // 确保手数不超过账户允许的最大值
        double maxLot = SymbolInfoDouble(m_Symbol, SYMBOL_VOLUME_MAX);
        double lotSize = MathMin(m_CurrentLotSize, maxLot);

        if (signal == BuySignal)
        {
            double sl = ask - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = ask + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            if (m_Trade.Buy(lotSize, m_Symbol, ask, sl, tp, "Buy Entry"))
            {
                m_FirstTradeExecuted = true;
                m_WaitingForNewSignal = false;
            }
        }
        else if (signal == SellSignal)
        {
            double sl = bid + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = bid - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            if (m_Trade.Sell(lotSize, m_Symbol, bid, sl, tp, "Sell Entry"))
            {
                m_FirstTradeExecuted = true;
                m_WaitingForNewSignal = false;
            }
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
            return;

        // 检查是否有止损的交易
        SignalType lastSignal = NoSignal;
        bool hasStoppedOut = HasStoppedOutTradeToday(lastSignal);

        if (hasStoppedOut)
        {
            // 如果止损了，下一次交易方向相反，手数翻倍
            m_CurrentLotSize *= 2;
            if (m_CurrentLotSize > InpLotSize * InpMaxMultiplier)
            {
                m_TodayTradingFinished = true; // 达到最大手数限制，停止今日交易
                return;
            }

            // 确定下一次交易方向
            // SignalType nextSignal = (lastSignal == BuySignal) ? SellSignal : BuySignal;
            ExecuteTrade(lastSignal);
            return;
        }

        // 如果是今日首次交易且未执行过
        if (!m_FirstTradeExecuted && !m_WaitingForNewSignal)
        {
            m_FirstTradeSignal = TradeSignal();
            if (m_FirstTradeSignal != NoSignal)
            {
                ExecuteTrade(m_FirstTradeSignal);
            }
            else
            {
                m_WaitingForNewSignal = true;
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