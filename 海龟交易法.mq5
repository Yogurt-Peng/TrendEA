#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

// 海龟交易法则
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 678442;               // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpATRPeriod = 14;                         // ATR周期
input double InpSLATRMultiplier = 3.0;               // 止损ATR倍数
input double InpAddATRMultiplier = 1.5;              // 波动多少倍加仓
input int InpMaxAddition = 3;                        // 最大加仓次数

class CTurtleTradingLaw : public CStrategy
{
private:
    CTools *m_Tools;
    CATR *m_ATR;

public:
public:
    CTurtleTradingLaw(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_ATR = new CATR(symbol, timeFrame, InpATRPeriod);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };
    ~CTurtleTradingLaw() {};

    // 重写Initialize函数
    bool Initialize() override
    {

        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;
    };

    void OnDeinit(const int reason) {
    };
};
CTurtleTradingLaw *g_Strategy;
