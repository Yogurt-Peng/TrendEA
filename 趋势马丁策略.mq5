#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 1458341;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpRISValue = 10;                          // RSI参数
input int InpGridSpacing = 100;                      // 网格间距
input double InpAdditionMultiple = 2;                // 加仓倍数

class CTrendMartin : public CStrategy
{
private:
    CTools *m_Tools;
    CRSI *m_RSI;

public:
    CTrendMartin(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_RSI = new CRSI(symbol, timeFrame, InpRISValue);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CTrendMartin() {};

    bool Initialize() override
    {
        if (!m_RSI.Initialize())
        {
            // 打印错误码
            Print("RSI初始化失败,错误码:", GetLastError());
            return false;
        }

        ChartIndicatorAdd(0, 1, m_RSI.GetHandle());
        return true;
    };

    SignalType TradeSignal() override
    {
        // buySegnal rsi 上穿越 30
        if (m_RSI.GetValue(2) < 30 && m_RSI.GetValue(1) > 30)
        {
            return BuySignal;
        }

        // sellSignal rsi 下穿越 70
        if (m_RSI.GetValue(2) > 70 && m_RSI.GetValue(1) < 70)
        {
            return SellSignal;
        }

        return NoSignal;
    };

    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;


        
    };

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_RSI.GetHandle());
        delete m_RSI;
        delete m_Tools;
    };
};