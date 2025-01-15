#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
// 基本参数
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 1小时周期
input int InpBaseMagicNumber = 542824;          // 基础魔术号
input double LotSize = 0.01;                    // 交易手数
input int CompareBars = 5;                      // 均线发散比较K线数
input int EMA1Value = 50;                       // EMA1指标值
input int EMA2Value = 60;                       // EMA2指标值
input int EMA3Value = 80;                       // EMA3指标值

class CVegasTrendFollowing : public CStrategy
{
private:
    CTools *m_Tools;
    double m_LotSize;
    int m_CompareBars;

public:
    CMA *m_EMA1;
    CMA *m_EMA2;
    CMA *m_EMA3;
    CBollingerBands *bollinger;

public:
    CVegasTrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber, double lotSize) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_LotSize = lotSize;
        m_CompareBars = CompareBars;
        m_EMA1 = new CMA(symbol, timeFrame, EMA1Value, MODE_EMA);
        m_EMA2 = new CMA(symbol, timeFrame, EMA2Value, MODE_EMA);
        m_EMA3 = new CMA(symbol, timeFrame, EMA3Value, MODE_EMA);
        bollinger = new CBollingerBands(symbol, timeFrame, 20, 2);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CVegasTrendFollowing() {};
    // 初始化方法
    bool Initialize() override
    {
        if (!m_EMA1.Initialize() || !m_EMA2.Initialize() || !bollinger.Initialize() || !m_EMA3.Initialize())
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
        SignalType signal = NoSignal;
        // 是否多头排列
        if (m_EMA1.GetValue(1) > m_EMA2.GetValue(1) && m_EMA2.GetValue(1) > m_EMA3.GetValue(1))
        {
            signal = BuySignal;
        }
        // 是否空头排列
        else if (m_EMA1.GetValue(1) < m_EMA2.GetValue(1) && m_EMA2.GetValue(1) < m_EMA3.GetValue(1))
        {
            signal = SellSignal;
        }

        // 是否发散
        for (int i = 1; i <= m_CompareBars; i++)
        {
            if (m_EMA1.GetValue(i) > m_EMA1.GetValue(i + 1) && m_EMA2.GetValue(i) > m_EMA2.GetValue(i + 1) && m_EMA3.GetValue(i) > m_EMA3.GetValue(i + 1))
            {
                signal = BuySignal;
            }

            if (m_EMA1.GetValue(i) < m_EMA1.GetValue(i + 1) && m_EMA2.GetValue(i) < m_EMA2.GetValue(i + 1) && m_EMA3.GetValue(i) < m_EMA3.GetValue(i + 1))
            {
                signal = SellSignal;
            }
        }

        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(m_Symbol, m_Timeframe, 1, 1, rates);
        // 阳线，最低价在布林带下轨之下，开盘价在布林带下轨之上
        if (signal == BuySignal && rates[0].close > rates[0].open && rates[0].low < bollinger.GetValue(2, 1) && rates[0].open > bollinger.GetValue(2, 1)&& rates[0].close > m_EMA3.GetValue(1))
        {
            return BuySignal;
        }
        // 阴线，最高价在布林带上轨之上，开盘价在布林带上轨之下
        if (signal == SellSignal && rates[0].close < rates[0].open && rates[0].high > bollinger.GetValue(1, 1) && rates[0].open < bollinger.GetValue(1, 1)&& rates[0].close < m_EMA3.GetValue(1))
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
        m_Tools.ApplyTrailingStopByHighLow(10, m_MagicNumber);

        SignalType signal = CheckSignal();
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        double sellSl = iHigh(m_Symbol, m_Timeframe, iHighest(m_Symbol, m_Timeframe, MODE_HIGH, 2, 1)) + SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        double buySl = iLow(m_Symbol, m_Timeframe, iLowest(m_Symbol, m_Timeframe, MODE_LOW, 2, 1)) - SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber) == 0)
        {
            m_Trade.Buy(m_LotSize, m_Symbol, buySl);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber) == 0)
        {
            m_Trade.Sell(m_LotSize, m_Symbol, bid, sellSl);
        }

        // 止盈止损
    };
    // 清理
    void ExitTrade() override
    {

    }
};
// 当最近N 根线的最高价或者最低价 大于或小于止损价格时候，更改止损价格到最近N根线的最高价或者最低价

CVegasTrendFollowing *VegasTrendFollowing;
int OnInit()
{
    VegasTrendFollowing = new CVegasTrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber, LotSize);
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