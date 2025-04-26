#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "---->画线价格提醒策略";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;                                                      // 时间周期
input string InpSymbols = "XAUUSDc|BTCUSDc|EURUSDc|AUDUSDc|GBPUSDc|USDCHFc|USDCADc|USDJPYc|NZDUSDc"; // 交易品种
input int InpMagicNumber = 542824;                                                                   // 基础魔术号
input int InpBarsBack = 15;
input int InpBarsBjBack = 100;     // 回溯周期
input int InpCoolDownBarCount = 3; // 冷却周期

string SymbolsArray[];
int SymbolsCount;

class CTrendFollow : public CStrategy
{
private:
    CTools *m_Tools;
    CMA *m_EMA_1;
    CMA *m_EMA_2;
    CMA *m_EMA_3;
    int m_CoolDownBarCount; // 冷却周期计数器，邮件触发后设为2，之后每个新K线减1

public:
    CTrendFollow(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber)
        : CStrategy(symbol, timeFrame, magicNumber), m_CoolDownBarCount(0)
    {
        m_EMA_1 = new CMA(m_Symbol, m_Timeframe, 21, MODE_EMA);
        m_EMA_2 = new CMA(m_Symbol, m_Timeframe, 34, MODE_EMA);
        m_EMA_3 = new CMA(m_Symbol, m_Timeframe, 55, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CTrendFollow() {};

    // 检查回溯周期内所有K线收盘价是否均在EMA上方或下方
    SignalType TradeSignal()
    {
        bool allBarsAboveEMA = true;
        bool allBarsBelowEMA = true;

        bool bgIsLong = true;
        bool bgIsShort = true;

        for (int i = 2; i <= InpBarsBack + 1; i++)
        {
            double close = iClose(m_Symbol, m_Timeframe, i);
            double ema = m_EMA_1.GetValue(i);
            if (close <= ema)
                allBarsAboveEMA = false;
            if (close >= ema)
                allBarsBelowEMA = false;
            if (!allBarsAboveEMA && !allBarsBelowEMA)
                break;
        }

        for (int i = 2; i <= InpBarsBjBack + 1; i++)
        {
            double ema2 = m_EMA_2.GetValue(i);
            double ema3 = m_EMA_3.GetValue(i);
            if (ema2 <= ema3)
                bgIsLong = false;
            if (ema2 >= ema3)
                bgIsShort = false;
            if (!bgIsLong && !bgIsShort)
                break;
        }

        if (allBarsAboveEMA && bgIsLong)
        {
            if (m_EMA_1.GetValue(1) > m_EMA_2.GetValue(1) && m_EMA_2.GetValue(1) > m_EMA_3.GetValue(1))
                return BuySignal;
        }
        if (allBarsBelowEMA && bgIsShort)
        {
            if (m_EMA_1.GetValue(1) < m_EMA_2.GetValue(1) && m_EMA_2.GetValue(1) < m_EMA_3.GetValue(1))
                return SellSignal;
        }
        return NoSignal;
    }

    bool Initialize() override
    {
        if (!m_EMA_1.Initialize() || !m_EMA_2.Initialize() || !m_EMA_3.Initialize())
        {
            Print("EMA 初始化失败");
            return false;
        }
        ChartIndicatorAdd(0, 0, m_EMA_1.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMA_2.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMA_3.GetHandle());
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    void OnTick() override
    {
        // 仅在新K线时执行
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        // 如果处于冷却周期内，则不检测信号，并减少冷却计数
        if (m_CoolDownBarCount > 0)
        {
            m_CoolDownBarCount--;
            return;
        }

        SignalType sign = TradeSignal();
        double currentEMA = m_EMA_1.GetValue(1);
        double high = iHigh(m_Symbol, m_Timeframe, 1);
        double low = iLow(m_Symbol, m_Timeframe, 1);

        if (sign == BuySignal && low < currentEMA)
        {
            string subject = StringFormat("Buy %s %s", m_Symbol, EnumToString(m_Timeframe));
            Print(subject);
            SendEmail(subject, "Strategy: 趋势回调");
            m_CoolDownBarCount = InpCoolDownBarCount; // 触发后接下来的2个周期不再触发
        }
        else if (sign == SellSignal && high > currentEMA)
        {
            string subject = StringFormat("Sell %s %s", m_Symbol, EnumToString(m_Timeframe));
            Print(subject);
            SendEmail(subject, "Strategy: 趋势回调");
            m_CoolDownBarCount = InpCoolDownBarCount; // 触发后接下来的2个周期不再触发
        }
    }

    void OnDeinit(const int reason) override
    {
        IndicatorRelease(m_EMA_1.GetHandle());
    }
};

CTrendFollow *StrategyArray[30]; // 每个周期最多创建30个实例（本例仅用到1个周期）

// 根据品种和周期索引生成唯一魔术号
int GenerateMagicNumber(int baseMagicNumber, int symbolIndex, int timeframeIndex)
{
    return baseMagicNumber + symbolIndex * 100 + timeframeIndex;
}

int OnInit()
{
    // 分割交易品种字符串
    ushort uSep = StringGetCharacter("|", 0);
    SymbolsCount = StringSplit(InpSymbols, uSep, SymbolsArray);

    // 为每个品种创建策略实例
    for (int i = 0; i < SymbolsCount; i++)
    {
        StrategyArray[i] = new CTrendFollow(SymbolsArray[i], InpTimeframe,
                                            GenerateMagicNumber(InpMagicNumber, i, 0));
        if (!StrategyArray[i].Initialize())
        {
            Print("Failed to initialize strategy for ", SymbolsArray[i]);
            return INIT_FAILED;
        }
    }
    return INIT_SUCCEEDED;
}

void OnTick()
{
    for (int i = 0; i < SymbolsCount; i++)
        StrategyArray[i].OnTick();
}

void OnDeinit(const int reason)
{
    for (int i = 0; i < SymbolsCount; i++)
        StrategyArray[i].OnDeinit(reason);
}
