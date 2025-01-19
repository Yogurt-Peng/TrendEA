#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 1小时周期
input int InpBaseMagicNumber = 4245111;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpMAFast = 7;                             // 快速EMA
input int InpEMASlow = 20;                           // 慢速EMA
input int InpCalculateCount = 20;                    // 计算信号的K线数量

class CAbandoningBar : public CStrategy
{

private:
    CTools *m_Tools;

public:
    CMA *m_EMAFast;
    CMA *m_EMASlow;

public:
    CAbandoningBar(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CAbandoningBar() {};

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
        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(m_Symbol, m_Timeframe, 1, InpCalculateCount, rates);

        // 20根K中最后一根K线的最高价-最低价的绝对值是这20根K线的最大振幅
        bool isMaximumAmplitude = true;
        double maxAmplitude = 0;
        for (int i = 1; i < InpCalculateCount; i++)
        {
            // 计算最后一根K线的振幅
            double LastBarAmplitude = MathAbs(rates[0].high - rates[0].low);
            double BarAmplitude = MathAbs(rates[i].high - rates[i].low);
            if (LastBarAmplitude < BarAmplitude)
            {
                return NoSignal;
            }
            maxAmplitude = BarAmplitude;
        }
        // 如果最近5根K线的振幅大于最大振幅的75%，且方向相反，则不交易
        if (rates[0].close > rates[0].open)
        {
            for (int i = 1; i <= 5; i++)
            {
                if (rates[i].close < rates[i].open)
                {
                    if (MathAbs(rates[i].close - rates[i].open) >= maxAmplitude * 0.75)
                    {
                        return NoSignal;
                    }
                }
            }
        }

        if (rates[0].close < rates[0].open)
        {
            for (int i = 1; i <= 5; i++)
            {
                if (rates[i].close > rates[i].open)
                {
                    if (MathAbs(rates[i].close - rates[i].open) >= maxAmplitude * 0.75)
                    {
                        return NoSignal;
                    }
                }
            }
        }

        // 多头排列
        if (m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1) && isMaximumAmplitude && rates[0].close > rates[0].open)
        {
            return BuySignal;
        }
        // 空头排列
        if (m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1) && isMaximumAmplitude && rates[0].close < rates[0].open)
        {
            return SellSignal;
        }

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        SignalType signal = TradeSignal();

        double barAmplitude = MathAbs(iClose(m_Symbol, m_Timeframe, 1) - iOpen(m_Symbol, m_Timeframe, 1));

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_BUY) == 0)
        {
            m_Trade.Buy(InpLotSize, _Symbol, ask, ask - barAmplitude, ask + barAmplitude);
        }
        else if (signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Trade.Sell(InpLotSize, _Symbol, bid, bid + barAmplitude, bid - barAmplitude);
        }
    };

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_EMAFast.GetHandle());
        IndicatorRelease(m_EMASlow.GetHandle());
        delete m_EMAFast;
        delete m_EMASlow;
        delete m_Tools;
    };
};

CAbandoningBar *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CAbandoningBar(_Symbol, InpTimeframe, InpBaseMagicNumber);
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
