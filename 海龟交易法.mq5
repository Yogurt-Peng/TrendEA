#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

// 海龟交易法则
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 678442;               // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数

input int InpEntryDCPeriod = 20; // 入场DC周期
input int InpExitDCPeriod = 10;  // 出场DC周期

input int InpATRPeriod = 14;            // ATR周期
input double InpSLATRMultiplier = 3.0;  // 止损ATR倍数
input double InpAddATRMultiplier = 1.5; // 波动多少倍加仓
input int InpMaxAddition = 3;           // 最大加仓次数

class CTurtleTradingLaw : public CStrategy
{
private:
    CTools *m_Tools;
    CATR *m_ATR;
    CDonchian *m_DCEntry;
    CDonchian *m_DCExit;

    int m_PostionSize;
    double m_lastEntryPrice;
    double m_EntryAtr;
    SignalType m_Direction; // 交易方向

public:
    CTurtleTradingLaw(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_ATR = new CATR(symbol, timeFrame, InpATRPeriod);
        m_DCEntry = new CDonchian(symbol, timeFrame, InpEntryDCPeriod);
        m_DCExit = new CDonchian(symbol, timeFrame, InpExitDCPeriod);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Direction = NoSignal;

        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CTurtleTradingLaw() {};

    // 重写Initialize函数
    bool Initialize() override
    {
        if (!m_ATR.Initialize())
        {
            Print("Failed to initialize ATR indicator for ", m_Symbol);
            return false;
        }
        if (!m_DCEntry.Initialize())
        {
            Print("Failed to initialize DCEntry indicator for ", m_Symbol);
            return false;
        }
        if (!m_DCExit.Initialize())
        {
            Print("Failed to initialize DCExit indicator for ", m_Symbol);
            return false;
        }

        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        double close_1 = iClose(m_Symbol, m_Timeframe, 1);
        double close_2 = iClose(m_Symbol, m_Timeframe, 2);
        if (close_1 > m_DCEntry.Upper(1) && close_2 < m_DCEntry.Upper(1))
            return BuySignal;
        else if (close_1 < m_DCEntry.Lower(1) && close_2 > m_DCEntry.Lower(1))
            return SellSignal;
        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(PERIOD_M1))
            return;

        double buy = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sell = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        double buySl = buy - InpSLATRMultiplier * m_ATR.GetValue(1);
        double sellSl = sell + InpSLATRMultiplier * m_ATR.GetValue(1);

        if (buy < m_DCExit.Lower(1) && m_Direction == BuySignal)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            m_PostionSize = 0;
            m_lastEntryPrice = 0;
            m_EntryAtr = 0;
            m_Direction = NoSignal;
        }
        else if (sell > m_DCExit.Upper(1) && m_Direction == SellSignal)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL);
            m_PostionSize = 0;
            m_lastEntryPrice = 0;
            m_EntryAtr = 0;
            m_Direction = NoSignal;
        }

        if (m_Tools.GetPositionCount(m_MagicNumber) >= InpMaxAddition + 1)
            return;

        int postionCount = m_Tools.GetPositionCount(m_MagicNumber);

        SignalType signal = TradeSignal();

        if (signal == BuySignal && postionCount == 0 && m_Direction == NoSignal)
        {
            m_Trade.Buy(InpLotSize, m_Symbol, buy, buySl);
            m_lastEntryPrice = buy;
            m_PostionSize++;
            m_EntryAtr = m_ATR.GetValue(1);
            m_Direction = BuySignal;
        }
        else if (signal == SellSignal && postionCount == 0 && m_Direction == NoSignal)
        {
            m_Trade.Sell(InpLotSize, m_Symbol, sell, sellSl);
            m_lastEntryPrice = sell;
            m_PostionSize++;
            m_EntryAtr = m_ATR.GetValue(1);
            m_Direction = SellSignal;
        }

        if (m_PostionSize > 0)
        {
            if ((buy - m_lastEntryPrice) >= InpAddATRMultiplier * m_EntryAtr && m_Direction == BuySignal)
            { // 多头加仓条件
                if (m_Direction != BuySignal)
                    return;
                m_Trade.Buy(InpLotSize, m_Symbol, buy, buySl);
                m_lastEntryPrice = buy;
                m_PostionSize++;
                Print("多头加仓");
            }
            else if ((m_lastEntryPrice - sell) >= InpAddATRMultiplier * m_EntryAtr && m_Direction == SellSignal)
            { // 空头加仓条件

                m_Trade.Sell(InpLotSize, m_Symbol, sell, sellSl);
                m_PostionSize++;
                m_lastEntryPrice = sell;
                Print("空头加仓");
            }
        }
    };

    void OnDeinit(const int reason) {
    };
};
CTurtleTradingLaw *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CTurtleTradingLaw(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return INIT_FAILED;
    }
    return (INIT_SUCCEEDED);
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    g_Strategy.OnDeinit(reason);
}
