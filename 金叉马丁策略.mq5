#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

// 基本参数  US500 DAY 最佳
input group "----->黄金参数";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 245454;               // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数

input int InpEMAFast = 13; // 慢速EMAb
input int InpEMASlow = 21; // 快速EMA

input int InpEMAFastA = 39; // 慢速EMAb
input int InpEMASlowB = 63; // 快速EMA

input double InpTakeProfit = 0.5; // 止盈点数
input double InpStopLoss = 5;     // 止损点数

class CALMATrendFollowing : public CStrategy
{
private:
    CTools *m_Tools;
    int m_counter; // 记录开仓次数

public:
    CWilliamsR *m_WilliamsR;
    CMA *m_EMAFast;
    CMA *m_EMASlow;

    CMA *m_EMAFastA;
    CMA *m_EMASlowB;

public:
    CALMATrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber)
        : CStrategy(symbol, timeFrame, magicNumber), m_counter(0)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpEMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_EMAFastA = new CMA(symbol, timeFrame, InpEMAFastA, MODE_EMA);
        m_EMASlowB = new CMA(symbol, timeFrame, InpEMASlowB, MODE_EMA);

        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }

    ~CALMATrendFollowing()
    {
        delete m_EMAFast;
        delete m_EMASlow;
        delete m_Tools;
    }

    bool Initialize() override
    {
        if (!m_EMAFast.Initialize() || !m_EMASlow.Initialize())
        {
            Print("Failed to initialize EMAs");
            return false;
        }
        if (!m_EMAFastA.Initialize() || !m_EMASlowB.Initialize())
        {
            Print("Failed to initialize EMAs");
            return false;
        }

        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMAFastA.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlowB.GetHandle());
        return true;
    }

    SignalType TradeSignal() override
    {
        // 金叉条件：EMAfast上穿EMAslow且形成两周期趋势反转
        bool buyCond1 = m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1);
        bool buyCond2 = m_EMAFast.GetValue(2) < m_EMASlow.GetValue(2);

        if (buyCond1 && buyCond2)
            return BuySignal;

        return NoSignal;
    }

    SignalType TradeSignalA()
    {
        // 金叉条件：EMAfast上穿EMAslow且形成两周期趋势反转
        bool buyCond1 = m_EMAFastA.GetValue(1) > m_EMASlowB.GetValue(1);
        bool buyCond2 = m_EMAFastA.GetValue(2) < m_EMASlowB.GetValue(2);

        if (buyCond1 && buyCond2)
            return BuySignal;

        return NoSignal;
    }

    void ExecuteTrade() override
    {

        // 检查强制平仓条件
        double totalProfit = m_Tools.GetTotalProfit(m_MagicNumber);
        if (totalProfit > InpTakeProfit || totalProfit < -InpStopLoss)
        {
            Print("强制平仓：总利润", totalProfit);
            m_Tools.CloseAllPositions(m_MagicNumber);
            m_counter = 0; // 平仓后计数器归零
            return;
        }

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        SignalType signal = TradeSignal();
        if (m_counter >= 1)
        {
            signal = TradeSignalA();
        }

        if (signal == BuySignal)
        {
            // 开立多仓
            m_Trade.Buy(InpLotSize);
            m_counter++;
            Print("开多仓，计数器：", m_counter);
        }
    }

    void OnDeinit(const int reason)
    {
        // IndicatorRelease(m_EMAFast.GetHandle());
        // IndicatorRelease(m_EMASlow.GetHandle());
        m_counter = 0; // 策略结束时重置计数器
    }
};

CALMATrendFollowing *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{
    g_Strategy = new CALMATrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
        return INIT_FAILED;
    return INIT_SUCCEEDED;
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    g_Strategy.OnDeinit(reason);
}