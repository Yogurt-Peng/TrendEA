#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 1小时周期
input int InpBaseMagicNumber = 4245111;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpMAFast = 7;                             // 快速EMA
input int InpEMASlow = 20;                           // 慢速EMA
input int InpCalculateCount = 20;                    // 计算信号的K线数量

class CAbandoningBar : public CStrategy
{

private:
    CTools *m_Tools;

public:
    CMA *m_EMAFast;
    CMA *m_EMASlow;

public:
    CAbandoningBar(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CAbandoningBar() {};

    bool Initialize() override
    {
        if (!m_EMAFast.Initialize())
        {
            Print("Failed to initialize EMAFast indicator for ", m_Symbol);
            return false;
        }
        if (!m_EMASlow.Initialize())
        {
            Print("Failed to initialize EMASlow indicator for ", m_Symbol);
            return false;
        }
        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        return true;
    };

    // 检查最近5个柱子的幅度是否超过最大幅度的75%
    bool CheckRecentBars(const MqlRates &rates[], double maxAmplitude, int index)
    {
        // 遍历最近5个柱子
        for (int i = 1; i <= 5; i++)
        {
            // 如果当前柱子的收盘价大于开盘价，而第i个柱子的收盘价小于开盘价，或者当前柱子的收盘价小于开盘价，而第i个柱子的收盘价大于开盘价
            if ((rates[index].close > rates[index].open && rates[i].close < rates[i].open) ||
                (rates[index].close < rates[index].open && rates[i].close > rates[i].open))
            {
                // 如果第i个柱子的幅度大于最大幅度的75%
                if (MathAbs(rates[i].close - rates[i].open) >= maxAmplitude * 0.75)
                {
                    // 返回true
                    return true;
                }
            }
        }
        // 如果没有找到符合条件的柱子，返回false
        return false;
    }

    // 获取交易信号
    SignalType TradeSignal() override
    {
        // 定义一个MqlRates类型的数组
        MqlRates rates[];
        // 将数组设置为系列
        ArraySetAsSeries(rates, true);
        // 复制指定数量的数据到数组中
        CopyRates(m_Symbol, m_Timeframe, 1, InpCalculateCount, rates);

        // 获取第一个数据的高点和低点的差值
        double maxAmplitude = MathAbs(rates[0].high - rates[0].low);
        // 遍历数组中的数据
        for (int i = 1; i < InpCalculateCount; i++)
        {
            // 获取当前数据的高点和低点的差值
            double BarAmplitude = MathAbs(rates[i].high - rates[i].low);
            // 如果当前数据的差值大于最大差值，则返回无信号
            if (maxAmplitude < BarAmplitude)
            {
                return NoSignal;
            }
        }

        // 检查最近的数据是否满足条件，如果满足则返回无信号
        if (CheckRecentBars(rates, maxAmplitude, 0))
        {
            return NoSignal;
        }

        // 多头排列
        if (m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1) && rates[0].close > rates[0].open)
        {
            return BuySignal;
        }
        // 空头排列
        if (m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1) && rates[0].close < rates[0].open)
        {
            return SellSignal;
        }

        return NoSignal;
    }
    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        SignalType signal = TradeSignal();

        double barAmplitude = MathAbs(iClose(m_Symbol, m_Timeframe, 1) - iOpen(m_Symbol, m_Timeframe, 1));

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_BUY) == 0)
        {
            m_Trade.Buy(InpLotSize, _Symbol, ask, ask - barAmplitude, ask + barAmplitude);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Trade.Sell(InpLotSize, _Symbol, bid, bid + barAmplitude, bid - barAmplitude);
        }
    };

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_EMAFast.GetHandle());
        IndicatorRelease(m_EMASlow.GetHandle());
        delete m_EMAFast;
        delete m_EMASlow;
        delete m_Tools;
    };
};

CAbandoningBar *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CAbandoningBar(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return (INIT_FAILED);
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
