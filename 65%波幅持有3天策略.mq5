#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H4; // 周期
input int InpBaseMagicNumber = 155965;          // 基础魔术号
input double InpLotSize = 0.1;                  // 交易手数
input int exitHours = 104;                      // 持有小时数
input double InpWave = 0.8;                     // 波幅

input int InpEMAFast = 5;  // 慢速EMA
input int InpEMASlow = 14; // 快速EMA

input bool InpLong = true;   // 做多
input bool InpShort = false; // 做空

class CALMATrendFollowing : public CStrategy
{
public:
    CTools *m_Tools;
    int m_EntryBar;       // 记录入场K线索引
    datetime m_EntryTime; // 记录入场时间
    CMA *m_EMAFast;
    CMA *m_EMASlow;

public:
    CALMATrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpEMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        m_EntryBar = -1;
    };
    ~CALMATrendFollowing() {};

    // 重写Initialize函数
    bool Initialize() override
    {
        // 初始化EMAFast指标
        if (!m_EMAFast.Initialize())
        {
            Print("Failed to initialize EMAFast indicator for ", m_Symbol);
            return false;
        }
        // 初始化EMASlow指标
        if (!m_EMASlow.Initialize())
        {
            Print("Failed to initialize EMASlow indicator for ", m_Symbol);
            return false;
        }
        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        double priceRange = iHigh(m_Symbol, m_Timeframe, 1) - iLow(m_Symbol, m_Timeframe, 1); // 当前K线的波幅
        double thresholdLong = iLow(m_Symbol, m_Timeframe, 1) + priceRange * InpWave;         // 临界值
        double thresholdShort = iHigh(m_Symbol, m_Timeframe, 1) - priceRange * InpWave;

        double close = iClose(m_Symbol, m_Timeframe, 1);
        double open = iOpen(m_Symbol, m_Timeframe, 1);
        if (close > thresholdLong && m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1))
        {
            return BuySignal;
        }
        else if (close < thresholdShort && m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1))
        {
            /* code */
            return SellSignal;
        }

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        if (m_EntryTime + exitHours * 3600 < TimeCurrent())
        {
            m_Tools.CloseAllPositions(m_MagicNumber);
        }

        if (m_Tools.GetPositionCount(m_MagicNumber))
            return;

        SignalType signal = TradeSignal();

        double high = iHigh(m_Symbol, m_Timeframe, 1);
        double low = iLow(m_Symbol, m_Timeframe, 1);

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_BUY) == 0)
        {
            if (InpLong)
            {
                m_Trade.Buy(InpLotSize);
                m_EntryTime = iTime(m_Symbol, m_Timeframe, 1);
            }
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            if (InpShort)
            {
                m_Trade.Sell(InpLotSize);
                m_EntryTime = iTime(m_Symbol, m_Timeframe, 1);
            }
        }
    };

    void OnDeinit(const int reason) {
    };
};
CALMATrendFollowing *g_Strategy;

int OnInit()
{

    g_Strategy = new CALMATrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return INIT_FAILED;
    }
    EventSetTimer(60); // 设置定时器，每30秒执行一次OnTimer函数

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