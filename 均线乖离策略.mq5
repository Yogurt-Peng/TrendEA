#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 周期
input int InpBaseMagicNumber = 155965;          // 基础魔术号
input double InpLotSize = 0.01;                 // 交易手数
input int InpEMA = 20;                          // EMA
input int InpATR = 14;                          // ATR
input double InpUpper = 2.5;                    // 上轨

// AUDUSD  1H 14 16 1.5
// NZDUSD  1H 14 24 2.0
class CEMA : public CStrategy
{
public:
    CTools *m_Tools;
    CMA *m_EMA;
    CATR *m_ATR;

public:
    CEMA(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, InpEMA, MODE_EMA);
        m_ATR = new CATR(symbol, timeFrame, InpATR);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CEMA() {};

    // 重写Initialize函数
    /**************************** CodeGeeX Inline Diff ****************************/
    bool Initialize() override
    {
        // 初始化EMAFast指标
        if (!m_EMA.Initialize())
        {
            Print("Failed to initialize EMAFast indicator for ", m_Symbol);
            return false;
        }
        // 初始化EMASlow指标
        if (!m_ATR.Initialize())
        {
            Print("Failed to initialize ATR indicator for ", m_Symbol);
            return false;
        }
        ChartIndicatorAdd(0, 0, m_EMA.GetHandle());
        ChartIndicatorAdd(0, 1, m_ATR.GetHandle());
        return true;
    };
    /******************** 906cd6e8-297a-4c74-aab0-ca197ba7f3b4 ********************/

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {

        double deviationB = (iClose(m_Symbol, m_Timeframe, 2) - m_EMA.GetValue(2)) / m_ATR.GetValue(2); // 乖离值
        double deviationA = (iClose(m_Symbol, m_Timeframe, 1) - m_EMA.GetValue(1)) / m_ATR.GetValue(1); // 乖离值

        if (deviationB < InpUpper && deviationA > InpUpper)
            return SellSignal;

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        if (m_Tools.GetPositionCount(m_MagicNumber) > 0)
        {

            double deviationA = (iClose(m_Symbol, m_Timeframe, 1) - m_EMA.GetValue(1)) / m_ATR.GetValue(1); // 乖离值
            double deviationB = (iClose(m_Symbol, m_Timeframe, 2) - m_EMA.GetValue(2)) / m_ATR.GetValue(2); // 乖离值

            // 上穿过
            if (deviationA < 0 && deviationB > 0)
            {
                m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            }
            else if (deviationA > 0 && deviationB < 0)
            {
                m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL);
            }
            return;
        }

        SignalType signal = TradeSignal();

        if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Trade.Sell(InpLotSize);
        }
    };

    void OnDeinit(const int reason) {
    };
};
CEMA *g_Strategy;

int OnInit()
{

    g_Strategy = new CEMA(_Symbol, InpTimeframe, InpBaseMagicNumber);
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

void OnTimer()
{
    if (!MQLInfoInteger(MQL_TESTER))
    {
        // 绘制时间
        printf(StringFormat("时间: %s", TimeToString(TimeLocal())));
    }
}