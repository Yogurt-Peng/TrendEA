#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 1小时周期
input int InpBaseMagicNumber = 42451;                // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpStopLoss = 100;                         // 止损点数 0:不使用
input int InpTakeProfit = 100;                       // 止盈点数 0:不使用
input int InpRISValue = 14;                          // RSI参数
input int InpBBValue = 20;                           // 布林带参数
input int InpBBDeviation = 2;                        // Bollinger Bands指标值

class CRSIBollingerBands : public CStrategy
{
private:
    CTools *m_Tools;
    CRSI *m_RSI;
    CBollingerBands *m_BB;

public:
    CRSIBollingerBands(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber, int rsiValue, int bbValue, int bbDeviation) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_RSI = new CRSI(symbol, timeFrame, rsiValue);
        m_BB = new CBollingerBands(symbol, timeFrame, bbValue, bbDeviation);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CRSIBollingerBands() {};

    bool Initialize() override
    {
        if (!m_RSI.Initialize())
        {
            Print("Failed to initialize RSI indicator for ", m_Symbol);
            return false;
        }
        if (!m_BB.Initialize())
        {
            Print("Failed to initialize Bollinger Bands indicator for ", m_Symbol);
            return false;
        }
        return true;
    }

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {


        return NoSignal;
    };
    // 执行交易
    void ExecuteTrade() override {

    };

    // 清理
    void ExitTrade() override
    {
        delete m_RSI;
        delete m_BB;
        delete m_Tools;
        IndicatorRelease(m_RSI.GetHandle());
        IndicatorRelease(m_BB.GetHandle());
    };
};
