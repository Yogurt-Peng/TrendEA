#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_D1; // 周期
input int InpBaseMagicNumber = 4245111;         // 基础魔术号
input int InpFastEMA = 12;                      // 快速EMA
input int InpSlowEMA = 26;                      // 慢速EMA
input int InpSignalSMA = 9;                     // 信号线SMA

class CMACDAlerter : public CStrategy
{
private:
    CTools *m_Tools;

public:
    CMACD *m_MACD;

public:
    CMACDAlerter(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_MACD = new CMACD(symbol, timeFrame, InpFastEMA, InpSlowEMA, InpSignalSMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CMACDAlerter() {};

    // 初始化方法
    bool Initialize() override
    {
        if (!m_MACD.Initialize())
        {
            Print("Failed to initialize MACD indicator for ", m_Symbol);
            return false;
        }
        if (!ChartIndicatorAdd(0, 0, m_MACD.GetHandle()))
        {
            int error_code = GetLastError();
            PrintFormat("Failed to add MACD indicator to chart. Error code: %d", error_code);
            // 根据需要处理特定的错误代码
            return false;
        }

        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        // 上两次macd柱子的值
        double prevMacdA = m_MACD.GetValue(0, 3);
        // 上一次macd柱子的值
        double prevMacdB = m_MACD.GetValue(0, 2);
        // 当前macd柱子的值
        double currMacd = m_MACD.GetValue(0, 1);
        // 当前和上一次macd柱子的值大于0，且当前macd柱子的值小于上一次macd柱子的值 卖出
        if (prevMacdA > 0 && currMacd > 0 && prevMacdB > 0 && prevMacdB > prevMacdA && prevMacdB > currMacd)
        {
            return SellSignal;
        }
        else if (prevMacdA < 0 && prevMacdB < 0 && currMacd < 0 && prevMacdB < prevMacdA && prevMacdB < currMacd)
        {
            return BuySignal;
        }

        return NoSignal;
    }

    // 执行交易
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;
        SignalType signal = TradeSignal();
        if (signal == BuySignal)
        {
            // 打印日志信息
            string logMessage = StringFormat("MACD Symbol: %s, Timeframe: %s, Direction: Buy", m_Symbol, EnumToString(m_Timeframe));
            string logSubject = StringFormat("Buy %s %s", m_Symbol, EnumToString(m_Timeframe));
            Print(logMessage); // 输出日志
            // 发送邮件通知
            SendEmail(logSubject, logMessage);
        }
        else if (signal == SellSignal)
        {
            // 打印日志信息
            string logMessage = StringFormat("MACD Symbol: %s, Timeframe: %s, Direction: Sell", m_Symbol, EnumToString(m_Timeframe));
            string logSubject = StringFormat("Sell %s %s", m_Symbol, EnumToString(m_Timeframe));
            Print(logMessage); // 输出日志
            // 发送邮件通知
            SendEmail(logSubject, logMessage);
        }
    }

    // 清理
    void ExitTrade() override
    {
        IndicatorRelease(m_MACD.GetHandle());
    }
};

CMACDAlerter *g_Strategy = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_Strategy = new CMACDAlerter(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (g_Strategy == NULL)
    {
        Print("Failed to create MACD alerter!");
        return INIT_FAILED;
    }
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize MACD alerter!");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
};

void OnTick()
{
    if (g_Strategy != NULL)
    {
        g_Strategy.OnTick();
    }
};

void OnDeinit(const int reason)
{
    if (g_Strategy != NULL)
    {
        g_Strategy.OnDeinit(reason);
    }
};