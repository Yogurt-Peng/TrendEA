#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 时间周期
input int InpMagicNumber = 542824;                   // 魔术号
input int InpEMAValue = 60;                          // 快速均线

// 单均线策略提醒EA
class CSimpleMA : public CStrategy
{
private:
    CMA *m_EMA;
    CTools *m_Tools;

public:
    CSimpleMA(string symbol, ENUM_TIMEFRAMES timeFrame, int EMAValue, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, EMAValue, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CSimpleMA() {};

    // 重写初始化方法
    bool Initialize() override
    {
        if (!m_EMA.Initialize())
        {
            Print("Failed to initialize EMA indicator");
            return false;
        }
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    // 自定义信号逻辑
    SignalType CheckSignal() override
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        if (CopyRates(m_Symbol, m_Timeframe, 1, 1, rates) < 1)
        {
            Print("Failed to copy rates");
            return NoSignal;
        }
        // 回踩均线不破
        if (rates[0].high > m_EMA.GetValue(1) && m_EMA.GetValue(1) > (rates[0].close > rates[0].open ? rates[0].close : rates[0].open))
        {
            return SellSignal;
        }
        else if (rates[0].low < m_EMA.GetValue(1) && m_EMA.GetValue(1) < (rates[0].close > rates[0].open ? rates[0].open : rates[0].close))
        {
            return BuySignal;
        }

        return NoSignal;
    }
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;
        SignalType signal = CheckSignal();
        if (signal == BuySignal)
        {
            // 打印日志信息
            string logMessage = StringFormat("Symbol: %s, Timeframe: %s, Direction: Buy", m_Symbol, EnumToString(m_Timeframe));
            Print(logMessage); // 输出日志
            // 发送邮件通知
            SendEmail("Buy Signal", logMessage);
        }
        else if (signal == SellSignal)
        {
            // 打印日志信息
            string logMessage = StringFormat("Symbol: %s, Timeframe: %s, Direction: Sell", m_Symbol, EnumToString(m_Timeframe));
            Print(logMessage); // 输出日志
            // 发送邮件通知
            SendEmail("Sell Signal", logMessage);
        }
    }
};

int OnInit()
{
    
    return (INIT_SUCCEEDED);
}
void OnTick()
{
}

void OnDeinit(const int reason)
{
}