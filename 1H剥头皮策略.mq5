#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"
// 基本参数  US500 DAY 最佳
input group "----->欧美货币";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 564814;               // 基础魔术号
input double InpAccountPercentage = 0.1;
input group "----->高点低点";
input int InpDepth = 10;   // 深度
input int InpDevotion = 5; // 偏离
input int InpBackStep = 2;
input int InpDeleteOrlderTime = 10; // 删除订单时间（H）
input group "----->止盈止损";
input int InpStopLoss = 100;   // 止损
input int InpTakeProfit = 100; // 止盈
input group "----->跟踪止损";
input int InpTrailingStopPips = 20;     // 跟踪止损
input int TriggerTrailingStopPips = 10; // 触发跟踪止损

class CStrateging : public CStrategy
{
private:
    CTools *m_Tools;

    CDraw m_Draw;
    CZigzag *m_Zigzag;

public:
    CStrateging(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_Zigzag = new CZigzag(symbol, timeFrame, InpDepth, InpDevotion, InpBackStep);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }

    // 重写Initialize函数
    bool Initialize() override
    {
        if (!m_Zigzag.Initialize())
        {
            Print("Failed to initialize ZigZag indicator for ", m_Symbol);
            return false;
        }
        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {

        return NoSignal;
    };

    void OnTick() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        double m_LowesArray[];
        double m_HighesArray[];
        ZeroMemory(m_LowesArray);
        ZeroMemory(m_HighesArray);

        m_Zigzag.GetValues(0, 0, 1000, m_HighesArray);
        m_Zigzag.GetValues(1, 0, 1000, m_LowesArray);

        FilterZeroValues(m_HighesArray);
        FilterZeroValues(m_LowesArray);
        FilterSizeValues(m_HighesArray, m_LowesArray);
        FilterZeroValues(m_HighesArray);
        FilterZeroValues(m_LowesArray);

        if (ArraySize(m_LowesArray) < 3 || ArraySize(m_HighesArray) < 3)
            return;

        for (int i = 0; i < 3; i++)
        {
            ObjectDelete(0, IntegerToString(i));
        }

        Print("✔️[1H剥头皮策略.mq5:83]: m_LowesArray: ", ArraySize(m_LowesArray));
        // Print("✔️[1H剥头皮策略.mq5:84]: m_HighesArray: ", ArraySize(m_HighesArray));

        for (int i = 0; i < 3; i++)
        {
            m_Draw.DrawHorizontalLine(IntegerToString(i), m_LowesArray[i], clrRed, 1);
        }

        // m_Draw.DrawHorizontalLine("low", m_LowesArray[0], clrRed, 1);
    };

    void OnDeinit(const int reason) {

    };

    // 在CStrateging类中添加成员函数
    void FilterZeroValues(double &arr[])
    {
        int newSize = 0;
        for (int i = 0; i < ArraySize(arr); ++i)
        {
            if (arr[i] != 0.0)
            {
                arr[newSize++] = arr[i];
            }
        }
        ArrayResize(arr, newSize);
    }

    void FilterSizeValues(double &highArr[], double &lowArr[])
    {
        double close = iClose(m_Symbol, m_Timeframe, 1);
        int newSize = 0;
        for (int i = 0; i < ArraySize(highArr); i++)
        {
            if (highArr[i] > close)
            {
                highArr[newSize++] = highArr[i];
            }
        }
        ArrayResize(highArr, newSize);

        newSize = 0;
        for (int i = 0; i < ArraySize(lowArr); i++)
        {
            if (lowArr[i] < close)
            {
                lowArr[newSize++] = lowArr[i];
            }
        }
        ArrayResize(lowArr, newSize);

        for (int i = 0; i < ArraySize(highArr) - 1; i++)
        {
            if (highArr[i] < highArr[i + 1])
            {
                highArr[i + 1] = 0;
            }
        }

        for (int i = 0; i < ArraySize(lowArr) - 1; i++)
        {
            if (lowArr[i] > lowArr[i + 1])
            {
                lowArr[i + 1] = 0;
            }
        }
    };
};
CStrateging *g_Strategy;
//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CStrateging(_Symbol, InpTimeframe, InpBaseMagicNumber);
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
