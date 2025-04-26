#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5; // 时间周期
input int InpBaseMagicNumber = 34288;           // 基础魔术号
input double InpLotSize = 0.03;                 // 交易手数
input int InpEMA = 20;                          // EMA
input int InpFluctuatePoints = 200;             // 波动点数
class CVolatilityStrategy : public CStrategy
{
private:
    CTools *m_Tools;
    CMA *m_EMA;

public:
    CVolatilityStrategy(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, InpEMA, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
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
    void OnTick() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        // 13:30-20:00 才进行交易
        if (!TimeSession(13, 30, 20, 0, TimeCurrent()))
            return; // Skip trading outside this time period

        int positionCount = m_Tools.GetPositionCount(m_MagicNumber);
        if (positionCount >= 0)
            return;
        SignalType signal = TradeSignal();

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        if (signal == BuySignal)
        {
            double sl = ask - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = ask + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            m_Trade.Buy(InpLotSize, m_Symbol, ask, sl, tp, "Buy Entry 1");
        }
        else if (signal == SellSignal)
        {
            double sl = bid + InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double tp = bid - InpFluctuatePoints * SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            m_Trade.Sell(InpLotSize, m_Symbol, bid, sl, tp, "Sell Entry 1");
        }
    }
}
