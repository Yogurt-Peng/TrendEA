#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
// 基本参数
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 周期
input int InpBaseMagicNumber = 542824;          // 基础魔术号
input double LotSize = 0.01;                    // 交易手数
input int ALMAValue = 50;                       // ALMA指标值
input int ALMASigma = 6;                        // ALMASigam
input double ALMAOffset = 0.85;                 // ALMAOffset
input int EMAFast = 5;                          // 慢速EMA
input int EMASlow = 10;                         // 快速EMA
input bool InpUseTrailingStop = true;           // 是否使用移动止损
input int InpTrailingStop = 5;                  // 移动止损点数

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
        m_EMAFast = new CMA(symbol, timeFrame, EMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, EMASlow, MODE_EMA);
        m_ALMA = new CALMA(symbol, timeFrame, ALMAValue, ALMASigma, ALMAOffset);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CALMATrendFollowing() {};

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
        if (!m_ALMA.Initialize())
        {
            Print("Failed to initialize ALMA indicator for ", m_Symbol);
            return false;
        }
        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        // 多头排列
        if (m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) > m_ALMA.GetValue(1))
        {
            return BuySignal;
        }

        // 空头排列
        if (m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) < m_ALMA.GetValue(1))
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
            m_Trade.Buy(LotSize);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            m_Trade.Sell(LotSize);
        }
    };
};
CALMATrendFollowing *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{
    g_Strategy = new CALMATrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (g_Strategy.Initialize())
    {
        Print("Strategy initialized successfully!");
    }
    else
    {
        Print("Failed to initialize strategy!");
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
