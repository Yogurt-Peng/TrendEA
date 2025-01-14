#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
// 基本参数
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 1小时周期
input int InpBaseMagicNumber = 542824;          // 基础魔术号
input int RSIValue = 14;                        // RSI 周期
input int ATRValue = 14;                        // ATR 周期
input double LotSize = 0.01;                    // 交易手数
input int CompareBars = 5;                      // 均线发散比较K线数
input double SLMultiplier = 1.5;                // 止损倍数
input double TPMultiplier = 1.5;                // 止盈倍数

class CVegasTrendFollowing : public CStrategy
{
private:
    CTools *m_Tools;
    double m_LotSize;
    int m_CompareBars;

public:
    CMA *m_EMA1;
    CMA *m_EMA2;
    CRSI *m_RSI;
    CATR *m_ATR;

public:
    CVegasTrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int rsiValue, int atrValue, int magicNumber, double lotSize, int compareBars) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_LotSize = lotSize;
        m_CompareBars = compareBars;
        m_EMA1 = new CMA(symbol, timeFrame, 144, MODE_EMA);
        m_EMA2 = new CMA(symbol, timeFrame, 169, MODE_EMA);
        m_RSI = new CRSI(symbol, timeFrame, rsiValue);
        m_ATR = new CATR(symbol, timeFrame, atrValue);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CVegasTrendFollowing() {};
    // 初始化方法
    bool Initialize() override
    {
        if (!m_EMA1.Initialize() || !m_EMA2.Initialize() || !m_RSI.Initialize() || !m_ATR.Initialize())
        {
            Print("Failed to initialize EMA indicator for ", m_Symbol);
            return false;
        }
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    // 自定义信号逻辑
    SignalType CheckSignal() override
    {
        bool isBuySignal = true;  // 初始假设为true，用于验证连续条件
        bool isSellSignal = true; // 同上
        double close = iClose(m_Symbol, m_Timeframe, 1);
        for (int i = 1; i <= m_CompareBars; i++)
        {
            // 如果EMA差距不是连续增大，重置为false  上涨
            if ((m_EMA1.GetValue(i) - m_EMA2.GetValue(i)) <= (m_EMA1.GetValue(i + 1) - m_EMA2.GetValue(i + 1)))
            {
                isBuySignal = false;
            }
            // 如果EMA差距不是连续增大，重置为false 下跌
            if ((m_EMA2.GetValue(i) - m_EMA1.GetValue(i)) <= (m_EMA2.GetValue(i + 1) - m_EMA1.GetValue(i + 1)))
            {
                isSellSignal = false;
            }
        }

        if(isBuySignal && (m_EMA1.GetValue(1) < m_EMA2.GetValue(1)|| close < m_EMA1.GetValue(1)))
        {
            isBuySignal = false;
        }

        if(isSellSignal && (m_EMA1.GetValue(1) > m_EMA2.GetValue(1) || close > m_EMA1.GetValue(1)))
        {
            isSellSignal = false;
        }

        // 检查RSI指标是否符合条件
        double rsiCurrent = m_RSI.GetValue(1);
        double rsiPrevious = m_RSI.GetValue(2);

        // RSI上穿50，且满足买入条件
        if (isBuySignal && rsiPrevious < 50 && rsiCurrent > 50)
        {
            return BuySignal;
        }

        // RSI下穿50，且满足卖出条件
        if (isSellSignal && rsiPrevious > 50 && rsiCurrent < 50)
        {
            return SellSignal;
        }

        // 没有信号
        return NoSignal;
    };

    // 执行交易
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;
        SignalType signal = CheckSignal();
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber) == 0)
        {
            m_Trade.Buy(m_LotSize, m_Symbol, ask, ask - m_ATR.GetValue(1) * SLMultiplier, ask + m_ATR.GetValue(1) * TPMultiplier);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber) == 0)
        {
            m_Trade.Sell(m_LotSize, m_Symbol, bid, bid + m_ATR.GetValue(1) * SLMultiplier, bid - m_ATR.GetValue(1) * TPMultiplier);
        }

        // 止盈止损
    };
    // 清理
    void ExitTrade() override
    {
        IndicatorRelease(m_EMA1.GetHandle());
        IndicatorRelease(m_EMA2.GetHandle());
        IndicatorRelease(m_RSI.GetHandle());
    }
};
CVegasTrendFollowing *VegasTrendFollowing;
int OnInit()
{
    VegasTrendFollowing = new CVegasTrendFollowing(_Symbol, InpTimeframe, RSIValue, ATRValue, InpBaseMagicNumber, LotSize, CompareBars);
    if (!VegasTrendFollowing.Initialize())
    {
        Print("Failed to initialize strategy for ", _Symbol);
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

void OnTick()
{
    VegasTrendFollowing.OnTick();
}

void OnDeinit(const int reason)
{
    VegasTrendFollowing.OnDeinit(reason);
    delete VegasTrendFollowing;
}