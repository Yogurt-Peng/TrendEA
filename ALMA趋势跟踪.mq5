#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
// 基本参数  US500 DAY 最佳
input group "----->黄金参数";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input int InpBaseMagicNumber = 5424524;              // 基础魔术号
input double InpLotSize = 0.14;                      // 交易手数
input int InpALMAValue = 50;                         // ALMA指标值
input double InpALMASigma = 6.0;                     // ALMASigam
input double InpALMAOffset = 0.85;                   // ALMAOffset
input int InpEMAFast = 5;                            // 慢速EMA
input int InpEMASlow = 10;                           // 快速EMA
input bool InpLong = true;                           // 做多
input bool InpShort = true;                          // 做空
input group "----->移动止损";
input bool InpUseTrailingStop = true; // 是否使用移动止损
input int InpTrailingStop = 5;        // 移动止损点数

input group "----->仓位管理";
input bool InpUseKelly = false;      // 使用凯利公式
input double InpKellyFraction = 0.2; // 凯利分数
input double InpStopLoss = 40000;    // 止损点数
// 在hk50指数上测试无法盈利
// US500  40 6.0 0.4 7 10 8  Day  0.1
// USDJPY 50 6.0 0.85 5 10 5 Day 0.01
// XAUUSD 60 6.0 0.5 4 11 6 4H 0.01
class CALMATrendFollowing : public CStrategy
{
private:
    CTools *m_Tools;

public:
    CALMA *m_ALMA;
    CMA *m_EMAFast;
    CMA *m_EMASlow;

public:
    CALMATrendFollowing(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_EMAFast = new CMA(symbol, timeFrame, InpEMAFast, MODE_EMA);
        m_EMASlow = new CMA(symbol, timeFrame, InpEMASlow, MODE_EMA);
        m_ALMA = new CALMA(symbol, timeFrame, InpALMAValue, InpALMASigma, InpALMAOffset);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
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
        if (!m_ALMA.Initialize())
        {
            Print("Failed to initialize ALMA indicator for ", m_Symbol);
            return false;
        }
        ChartIndicatorAdd(0, 0, m_ALMA.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMAFast.GetHandle());
        ChartIndicatorAdd(0, 0, m_EMASlow.GetHandle());
        return true;
    };

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        // 多头排列且满足均线发散条件
        if (m_EMAFast.GetValue(1) > m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) > m_ALMA.GetValue(1))
        {
            return BuySignal;
        }

        // 空头排列且满足均线发散条件
        if (m_EMAFast.GetValue(1) < m_EMASlow.GetValue(1) && m_EMASlow.GetValue(1) < m_ALMA.GetValue(1))
        {
            return SellSignal;
        }

        return NoSignal;
    };

    void ExecuteTrade() override
    {

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        if (InpUseTrailingStop)
            m_Tools.ApplyTrailingStopByHighLow(InpTrailingStop, m_MagicNumber);

        SignalType signal = TradeSignal();

        double lotSize = KailiFormulaCalacte(0.35, 3.2, 84);

        Print("✔️[ALMA趋势跟踪.mq5:106]: lotSize: ", lotSize);

        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double buySl = ask - InpStopLoss * _Point;
        double sellSl = bid + InpStopLoss * _Point;

        if (InpLong && signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_BUY) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL);

            if (InpUseKelly)
                m_Trade.Buy(InpUseKelly ? lotSize : InpLotSize, m_Symbol, ask, buySl);
            else
                m_Trade.Buy(InpUseKelly ? lotSize : InpLotSize);
        }
        else if (InpShort && signal == SellSignal && m_Tools.GetPositionCount(m_MagicNumber, POSITION_TYPE_SELL) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            if (InpUseKelly)
                m_Trade.Sell(InpUseKelly ? lotSize : InpLotSize, m_Symbol, bid, sellSl);
            else
                m_Trade.Sell(InpUseKelly ? lotSize : InpLotSize);
        }
    };

    void OnDeinit(const int reason)
    {
        IndicatorRelease(m_ALMA.GetHandle());
        IndicatorRelease(m_EMAFast.GetHandle());
        IndicatorRelease(m_EMASlow.GetHandle());
    };

    double KailiFormulaCalacte(double winningRate, double plRate, double avgLoss)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);

        double f = (winningRate * (plRate + 1) - 1) / plRate;
        double lotSize = (balance * f) / avgLoss * 0.01 * InpKellyFraction;
        lotSize = NormalizeDouble(lotSize, 2);
        if (lotSize <= InpLotSize)
            lotSize = InpLotSize;
        return lotSize;
    };
};
CALMATrendFollowing *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{

    g_Strategy = new CALMATrendFollowing(_Symbol, InpTimeframe, InpBaseMagicNumber);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return INIT_FAILED;
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
