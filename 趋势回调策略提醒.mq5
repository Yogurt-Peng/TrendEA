#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "---->画线价格提醒策略";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;                      // 1小时周期
input string InpSymbols = "XAUUSDm|BTCUSDm|EURUSDm|AUDUSDm|GBPUSDm"; // 交易品种
input int InpMagicNumber = 542824;                                   // 基础魔术号
input int InpBarsBack = 15;                                          // 回溯周期
input int InpEMAPeriod = 20;                                         // EMA周期

string SymbolsArray[];
int SymbolsCount;

class CTrendFollow : public CStrategy

{
private:
    CTools *m_Tools;
    CMA *m_EMA;
    int m_EMAPeriod;

public:
    CTrendFollow(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber, int emaPeriod) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAPeriod = emaPeriod;
        m_EMA = new CMA(m_Symbol, m_Timeframe, emaPeriod, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CTrendFollow() {};

    SignalType TradeSignal()
    {
        // 检查买入条件：所有K线收盘价都在EMA上方
        bool allBarsAboveEMA = true;
        for (int i = 2; i <= InpBarsBack + 1; i++)
        {
            double close = iClose(m_Symbol, m_Timeframe, i);
            double low = iLow(m_Symbol, m_Timeframe, i);
            double ema = m_EMA.GetValue(i);

            if (low <= ema)
            {
                allBarsAboveEMA = false;
                break;
            }
        }

        // 检查卖出条件：所有K线收盘价都在EMA下方
        bool allBarsBelowEMA = true;
        for (int i = 2; i <= InpBarsBack + 1; i++)
        {
            double close = iClose(m_Symbol, m_Timeframe, i);
            double high = iHigh(m_Symbol, m_Timeframe, i);
            double ema = m_EMA.GetValue(i);

            if (high >= ema)
            {
                allBarsBelowEMA = false;
                break;
            }
        }

        // 信号优先级：同时满足时默认返回NoSignal
        if (allBarsAboveEMA)
            return BuySignal;
        if (allBarsBelowEMA)
            return SellSignal;
        return NoSignal;
    }

    bool Initialize() override
    {
        if (!m_EMA.Initialize())
        {
            Print("EMA 初始化失败");
            return false;
        }

        ChartIndicatorAdd(0, 0, m_EMA.GetHandle());
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }
    void OnTick() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        SignalType sign = TradeSignal();

        double open = iOpen(m_Symbol, m_Timeframe, 1);
        double close = iClose(m_Symbol, m_Timeframe, 1);
        double high = iHigh(m_Symbol, m_Timeframe, 1);
        double low = iLow(m_Symbol, m_Timeframe, 1);

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        if (sign == BuySignal)
        {
            if (low < m_EMA.GetValue(1))
            {
                // string logMessage = StringFormat("Symbol: %s, Timeframe: %s, Direction: Buy", m_Symbol, EnumToString(m_Timeframe));
                // string logSubject = StringFormat("Buy %s %s", m_Symbol, EnumToString(m_Timeframe));
                string logMessage = "Strategy: 趋势回调";
                string logSubject = StringFormat("Buy %s %s", m_Symbol, EnumToString(m_Timeframe));
                Print(logSubject); // 输出日志
                // 发送邮件通知
                SendEmail(logSubject, logMessage);
            }
        }

        if (sign == SellSignal)
        {
            if (high > m_EMA.GetValue(1))
            {
                string logMessage = "Strategy: 趋势回调";
                string logSubject = StringFormat("Sell %s %s", m_Symbol, EnumToString(m_Timeframe));
                Print(logSubject); // 输出日志
                // 发送邮件通知
                SendEmail(logSubject, logMessage);
            }
        }
    }
    void OnDeinit(const int reason) override
    {
        IndicatorRelease(m_EMA.GetHandle());
    }
};
CTrendFollow *StrategyArray[30]; // 3个周期，每个周期最多10个品种
// 为每个品种和周期生成不同的魔术号
int GenerateMagicNumber(int baseMagicNumber, int symbolIndex, int timeframeIndex)
{
    return baseMagicNumber + symbolIndex * 100 + timeframeIndex; // 通过品种和周期索引生成唯一魔术号
}
int OnInit()
{
    // 分割品种列表

    ushort uSep = StringGetCharacter("|", 0);
    SymbolsCount = StringSplit(InpSymbols, uSep, SymbolsArray);

    // 为每个品种和每个周期创建策略实例
    for (int i = 0; i < SymbolsCount; i++)
    {
        // 为每个品种和每个周期（1H, 4H, D1）创建策略实例，并为每个实例分配唯一的魔术号
        StrategyArray[i] = new CTrendFollow(SymbolsArray[i], InpTimeframe, GenerateMagicNumber(InpMagicNumber, i, 0), InpEMAPeriod); // 1小时周期
        if (!StrategyArray[i].Initialize())
        {
            Print("Failed to initialize SimpleMA strategy for ", SymbolsArray[i], " on 1H timeframe");
            return (INIT_FAILED);
        }
    }
    return (INIT_SUCCEEDED);
}

void OnTick()
{
    // 在每个品种的每个周期上运行OnTick
    for (int i = 0; i < SymbolsCount; i++)
    {
        StrategyArray[i].OnTick(); // 日线周期
    }
}

void OnDeinit(const int reason)
{
    // 清理每个策略实例
    for (int i = 0; i < SymbolsCount; i++)
    {
        StrategyArray[i].OnDeinit(reason); // 1小时周期
    }
}
