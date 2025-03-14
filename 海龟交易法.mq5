#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

// 海龟交易法则参数
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H2; // 周期
input int InpBaseMagicNumber = 4156454;         // 基础魔术号

input int InpLotType = 2;       // 1:手数,2:百分比
input double InpLotSize = 0.01; // 手数
input double InpMaxRisk = 1;    // 每个头寸的风险百分比

input int InpEntryDCPeriod = 20;        // 入场DC周期
input int InpExitDCPeriod = 15;         // 出场DC周期
input int InpATRPeriod = 14;            // ATR周期
input double InpSLATRMultiplier = 2.0;  // 止损ATR倍数
input double InpAddATRMultiplier = 0.5; // 波动多少倍加仓
input int InpMaxAddition = 2;           // 最大加仓次数
input bool InpLong = false;             // 做多
input bool InpShort = true;             // 做空

// XAUUSDc 8H 20 10 14 3 1.0
// US500c 2H 20 15 14 2 0.5

class CTurtleTradingLaw : public CStrategy
{
private:
    CTools *m_Tools;
    CATR *m_ATR;
    CDonchian *m_DCEntry;
    CDonchian *m_DCExit;

    int m_PositionSize;
    double m_LastEntryPrice;
    double m_EntryATR;
    SignalType m_Direction; // 交易方向

public:
    CTurtleTradingLaw(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber)
        : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_ATR = new CATR(symbol, timeFrame, InpATRPeriod);
        m_DCEntry = new CDonchian(symbol, timeFrame, InpEntryDCPeriod);
        m_DCExit = new CDonchian(symbol, timeFrame, InpExitDCPeriod);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Direction = NoSignal;

        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }

    ~CTurtleTradingLaw()
    {
        delete m_ATR;
        delete m_DCEntry;
        delete m_DCExit;
        delete m_Tools;
    }

    // 初始化指标
    bool Initialize() override
    {
        if (!m_ATR.Initialize() || !m_DCEntry.Initialize() || !m_DCExit.Initialize())
        {
            Print("Failed to initialize indicators for ", m_Symbol);
            return false;
        }

        ChartIndicatorAdd(0, 0, m_DCEntry.GetHandle());
        ChartIndicatorAdd(0, 0, m_DCExit.GetHandle());
        ChartIndicatorAdd(0, 1, m_ATR.GetHandle());
        return true;
    }

    // 生成交易信号
    SignalType TradeSignal() override
    {
        double close1 = iClose(m_Symbol, m_Timeframe, 1);
        double close2 = iClose(m_Symbol, m_Timeframe, 2);

        if (close1 > m_DCEntry.Upper(1) && close2 <= m_DCEntry.Upper(1))
            return BuySignal;
        if (close1 < m_DCEntry.Lower(1) && close2 >= m_DCEntry.Lower(1))
            return SellSignal;
        return NoSignal;
    }

    // 执行交易逻辑
    void ExecuteTrade() override
    {

        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double atrValue = m_ATR.GetValue(1);

        // 平仓逻辑
        if ((bid < m_DCExit.Lower(1) && m_Direction == BuySignal) || (ask > m_DCExit.Upper(1) && m_Direction == SellSignal))
        {
            CloseAllPositions();
            return;
        }
        m_PositionSize = m_Tools.GetPositionCount(InpBaseMagicNumber);
        // 加仓逻辑
        if (m_PositionSize > 0 && m_PositionSize <= InpMaxAddition)
        {
            if (m_Direction == BuySignal && (ask - m_LastEntryPrice) >= InpAddATRMultiplier * m_EntryATR)
            {
                AddPosition(ask, ask - InpSLATRMultiplier * atrValue, "Buy Addition");
            }
            else if (m_Direction == SellSignal && (m_LastEntryPrice - bid) >= InpAddATRMultiplier * m_EntryATR)
            {
                AddPosition(bid, bid + InpSLATRMultiplier * atrValue, "Sell Addition");
            }
        }

        if (!m_Tools.IsNewBar(PERIOD_M1))
            return;

        // 初始入场逻辑
        if (m_PositionSize == 0)
        {

            SignalType signal = TradeSignal();
            if (signal == BuySignal && InpLong)
            {

                OpenPosition(ask, ask - InpSLATRMultiplier * atrValue, "Buy Entry");
            }
            else if (signal == SellSignal && InpShort)
            {
                OpenPosition(bid, bid + InpSLATRMultiplier * atrValue, "Sell Entry");
            }
        }
    }

private:
    // 开仓
    void OpenPosition(double price, double sl, string comment)
    {
        m_Direction = (m_Direction == NoSignal) ? (comment == "Buy Entry" ? BuySignal : SellSignal) : m_Direction;
        double lotSize = 0;
        if (InpLotType == 2)
            lotSize = m_Tools.CalcLots(price, sl, InpMaxRisk);
        else
            lotSize = InpLotSize;

        if (m_Direction == BuySignal)
            m_Trade.Buy(lotSize, m_Symbol, price, sl, 0, comment);
        else
            m_Trade.Sell(lotSize, m_Symbol, price, sl, 0, comment);

        m_LastEntryPrice = price;
        m_EntryATR = m_ATR.GetValue(1);
        m_PositionSize++;
    }

    // 加仓
    void AddPosition(double price, double sl, string comment)
    {
        OpenPosition(price, sl, comment);
        ChangeAllOrderSLTP(sl);
        Print(comment);
    }

    // 平仓
    void CloseAllPositions()
    {
        m_Tools.CloseAllPositions(m_MagicNumber, m_Direction == BuySignal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
        m_PositionSize = 0;
        m_LastEntryPrice = 0;
        m_EntryATR = 0;
        m_Direction = NoSignal;
    }

    // 修改所有订单止损
    void ChangeAllOrderSLTP(double sl)
    {
        CPositionInfo positionInfo;
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if (positionInfo.SelectByIndex(i) && positionInfo.Magic() == m_MagicNumber && positionInfo.Symbol() == _Symbol)
            {
                if (!m_Trade.PositionModify(positionInfo.Ticket(), sl, 0))
                {
                    Print(_Symbol, "|", m_MagicNumber, " Failed to modify SL, Error: ", m_Trade.ResultRetcodeDescription());
                }
            }
        }
    }
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
    return INIT_SUCCEEDED;
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    delete g_Strategy;
}