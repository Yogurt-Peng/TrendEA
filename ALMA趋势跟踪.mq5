#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
// 基本参数
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber;                        // 基础魔术号
input double InpLotSize = 0.1;                       // 交易手数
input int InpALMAValue = 50;                         // ALMA指标值
input double InpALMASigma = 6.0;                     // ALMASigam
input double InpALMAOffset = 0.85;                   // ALMAOffset
input int InpEMAFast = 5;                            // 慢速EMA
input int InpEMASlow = 10;

input group "==============均线发散==============";
input bool InpUseDiverge = false; // 是否使用均线发散
input int InpDivergeBars = 4;     // 发散K线数量

input group "==============移动止损==============";
input bool InpUseTrailingStop = true; // 是否使用移动止损
input int InpTrailingStop = 6;        // 移动止损点数
input bool InpLong = true;            // 做多
input bool InpShort = true;           // 做空

// 在hk50指数上测试无法盈利
class CALMATrendFollowing : public CStrategy
{
private:
    CTools *m_Tools;

public:
    CALMA *m_ALMA;
    CMA *m_EMAFast;
    CMA *m_EMASlow;

public:
    CALMATrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpEMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_ALMA = new CALMA(symbol, timeFrame, InpALMAValue, InpALMASigma, InpALMAOffset);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CALMATrendFollowing() {};

    // 重写Initialize函数
    bool Initialize() override
    {
        // 初始化EMAFast指标
        if (!m_EMAFast.Initialize())
        {
            // 如果初始化失败，打印错误信息
            Print("Failed to initialize EMAFast indicator for ", m_Symbol);
            return false;
        }
        // 初始化EMASlow指标
        if (!m_EMASlow.Initialize())
        {
            // 如果初始化失败，打印错误信息
            Print("Failed to initialize EMASlow indicator for ", m_Symbol);
            return false;
        }
        // 初始化ALMA指标
        if (!m_ALMA.Initialize())
        {
            // 如果初始化失败，打印错误信息
            Print("Failed to initialize ALMA indicator for ", m_Symbol);
            return false;
        }
        // 将ALMA指标添加到图表中
        ChartIndicatorAdd(0, 0, m_ALMA.GetHandle());
        // 将EMAFast指标添加到图表中
        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        // 将EMASlow指标添加到图表中
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        // 返回true表示初始化成功
        return true;
    };

    // 自定义信号逻辑
    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        bool longDiverge = true;
        bool shortDiverge = true;
        // 均线发散
        if (InpUseDiverge)
        {
            for (int i = 1; i <= InpDivergeBars; i++)
            {
                if (!(m_EMAFast.GetValue(i) > m_EMAFast.GetValue(i + 1) && m_EMASlow.GetValue(i) > m_EMASlow.GetValue(i + 1)))
                {
                    longDiverge = false;
                }

                if (!(m_EMAFast.GetValue(i) < m_EMAFast.GetValue(i + 1) && m_EMASlow.GetValue(i) < m_EMASlow.GetValue(i + 1)))
                {
                    shortDiverge = false;
                }
            }
        }

        // 多头排列且满足均线发散条件
        if (longDiverge && m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) > m_ALMA.GetValue(1))
        {
            return BuySignal;
        }

        // 空头排列且满足均线发散条件
        if (shortDiverge && m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) < m_ALMA.GetValue(1))
        {
            return SellSignal;
        }

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        if (InpUseTrailingStop)
            m_Tools.ApplyTrailingStopByHighLow(InpTrailingStop, m_MagicNumber);

        SignalType signal = TradeSignal();

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_BUY) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL);
            if (InpLong)
                m_Trade.Buy(InpLotSize);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            if (InpShort)
                m_Trade.Sell(InpLotSize);
        }
    };

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_EMAFast.GetHandle());
        IndicatorRelease(m_EMASlow.GetHandle());
        IndicatorRelease(m_ALMA.GetHandle());
        delete m_EMAFast;
        delete m_EMASlow;
        delete m_ALMA;
        delete m_Tools;
    };
};
CALMATrendFollowing *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CALMATrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber);
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
