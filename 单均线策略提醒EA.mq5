#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

// 基本参数
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe1H = PERIOD_H1;    // 1小时周期
input ENUM_TIMEFRAMES InpTimeframe4H = PERIOD_H4;    // 4小时周期
input ENUM_TIMEFRAMES InpTimeframeDay = PERIOD_D1;   // 日线周期
input int InpBaseMagicNumber = 542824;               // 基础魔术号
input int InpEMAValue = 60;                          // 快速均线
input string InpSymbols = "XAUUSDm|BTCUSDm|AUDUSDm|EURUSDm|GBPUSDm|NZDUSDm|USDCADm|USDCHFm|USDJPYm|AUDCADm|AUDCHFm|AUDJPYm|AUDNZDm|CADCHFm|CADJPYm|CHFJPYm|EURAUDm|EURCHFm|EURGBPm|EURJPYm|EURNZDm|GBPAUDm|GBPCADm|GBPCHFm|GBPJPYm|GBPNZDm|NZDCADm|NZDCHFm|NZDJPYm"; // 交易品种

// 品种数组
string SymbolsArray[];
int SymbolsCount;

// 单均线策略
class CSimpleMA : public CStrategy
{
private:
    CTools *m_Tools;

public:
    CMA *m_EMA;

public:
    CSimpleMA(string symbol, ENUM_TIMEFRAMES timeFrame, int EMAValue, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMA = new CMA(symbol, timeFrame, EMAValue, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CSimpleMA() {};

    // 初始化方法
    bool Initialize() override
    {
        if (!m_EMA.Initialize())
        {
            Print("Failed to initialize EMA indicator for ", m_Symbol);
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
            Print("Failed to copy rates for ", m_Symbol);
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

    // 执行交易
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

    // 清理
    void ExitTrade() override
    {
        IndicatorRelease(m_EMA.GetHandle());
    }
};

// 用于存储策略实例的数组
CSimpleMA *SimpleMAArray[3][30]; // 3个周期，每个周期最多10个品种

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
        SimpleMAArray[0][i] = new CSimpleMA(SymbolsArray[i], InpTimeframe1H, InpEMAValue, GenerateMagicNumber(InpBaseMagicNumber, i, 0)); // 1小时周期
        if (!SimpleMAArray[0][i].Initialize())
        {
            Print("Failed to initialize SimpleMA strategy for ", SymbolsArray[i], " on 1H timeframe");
            return (INIT_FAILED);
        }

        SimpleMAArray[1][i] = new CSimpleMA(SymbolsArray[i], InpTimeframe4H, InpEMAValue, GenerateMagicNumber(InpBaseMagicNumber, i, 1)); // 4小时周期
        if (!SimpleMAArray[1][i].Initialize())
        {
            Print("Failed to initialize SimpleMA strategy for ", SymbolsArray[i], " on 4H timeframe");
            return (INIT_FAILED);
        }

        SimpleMAArray[2][i] = new CSimpleMA(SymbolsArray[i], InpTimeframeDay, InpEMAValue, GenerateMagicNumber(InpBaseMagicNumber, i, 2)); // 日线周期
        if (!SimpleMAArray[2][i].Initialize())
        {
            Print("Failed to initialize SimpleMA strategy for ", SymbolsArray[i], " on D1 timeframe");
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
        SimpleMAArray[0][i].OnTick(); // 1小时周期
        SimpleMAArray[1][i].OnTick(); // 4小时周期
        SimpleMAArray[2][i].OnTick(); // 日线周期
    }

    // int handle = ChartIndicatorGet(0, 0, "MA(" + IntegerToString(InpEMAValue) + ")"); // 从图表中指标句柄
    // if (handle == INVALID_HANDLE)
    // {
    //     // 如果没有找到EMA指标，则为当前品种和周期创建新的EMA
    //     for (int i = 0; i < SymbolsCount; i++)
    //     {
    //         // 检查每个品种和每个周期的策略实例
    //         for (int j = 0; j < 3; j++) // 假设有 3 个时间周期
    //         {
    //             // 如果当前品种和周期匹配，初始化EMA指标
    //             if (SimpleMAArray[j][i].Initialize())
    //             {
    //                 // 为当前品种和周期添加EMA并返回句柄
    //                 handle = SimpleMAArray[j][i].m_EMA.GetHandle();
    //                 if (handle == INVALID_HANDLE)
    //                 {
    //                     Print("Failed to get EMA handle for ", _Symbol, " on ", EnumToString(PERIOD_CURRENT), " timeframe");
    //                     return;
    //                 }
    //                 ChartIndicatorAdd(0, 0, handle);
    //             }
    //         }
    //     }
    // }
}

void OnDeinit(const int reason)
{
    // 清理每个策略实例
    for (int i = 0; i < SymbolsCount; i++)
    {
        SimpleMAArray[0][i].OnDeinit(reason); // 1小时周期
        SimpleMAArray[1][i].OnDeinit(reason); // 4小时周期
        SimpleMAArray[2][i].OnDeinit(reason); // 日线周期
    }
}
