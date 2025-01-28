#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/CPerformanceEvaluator.mqh"
input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 1小时周期
input int InpBaseMagicNumber = 45628;                // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpStopLoss = 300;                         // 止损点数 0:不使用
input int InpTakeProfit = 0;                         // 止盈点数 0:不使用
input int InpRISValue = 10;                          // RSI参数
input int InpMAValue = 30;                           // 均线参数
input bool InpLong = false;                          // 是否允许开多单
input bool InpShort = true;                          // 是否允许开空单

// RUSUSD 15min 300 0 10 30 2
class CRSIMA : public CStrategy
{
private:
    CTools *m_Tools;
    CRSI *m_RSI;
    CMA *m_MA;

public:
    CRSIMA(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber, int rsiValue, int maValue) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_RSI = new CRSI(symbol, timeFrame, rsiValue);
        m_MA = new CMA(symbol, timeFrame, maValue, MODE_SMA);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CRSIMA() {};

    bool Initialize() override
    {
        if (!m_RSI.Initialize())
        {
            Print("Failed to initialize RSI indicator for ", m_Symbol);
            return false;
        }
        if (!m_MA.Initialize())
        {
            Print("Failed to initialize MA  indicator for ", m_Symbol);
            return false;
        }
        return true;
    }

    // 自定义信号逻辑
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
    // 执行交易
    void ExecuteTrade() override
    {
        // 获取当前的买价和卖价
        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);

        // 检查获取报价是否成功
        if (ask == 0.0 || bid == 0.0)
        {
            Print("Failed to get ask or bid price for ", m_Symbol);
            return;
        }
        // 获取当前持仓数量
        int positionCount = m_Tools.GetPositionCount(m_MagicNumber);

        // 持仓管理
        if (positionCount > 0)
        {
            double ma = m_MA.GetValue(0);
            if (ask >= ma)
            {
                if (!m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY))
                {
                    Print("Failed to close all buy positions for ", m_Symbol);
                }
            }
            if (bid <= ma)
            {
                if (!m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL))
                {
                    Print("Failed to close all sell positions for ", m_Symbol);
                }
            }
        }

        // 检查是否为新的K线
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        positionCount = m_Tools.GetPositionCount(m_MagicNumber);

        // 获取交易信号
        SignalType signal = TradeSignal();

        // 计算止损和止盈价格
        double buySl = calculateStopLoss(ask, InpStopLoss);
        double sellSl = calculateStopLoss(bid, InpStopLoss, true);

        // 开仓逻辑
        if (signal == BuySignal && positionCount == 0)
        {
            if (InpLong)
            {
                if (!m_Trade.Buy(InpLotSize, m_Symbol, ask, buySl))
                {
                    Print("Failed to execute buy trade for ", m_Symbol);
                }
            }
        }
        else if (signal == SellSignal && positionCount == 0)
        {
            if (InpShort)
            {
                if (!m_Trade.Sell(InpLotSize, m_Symbol, bid, sellSl))
                {
                    Print("Failed to execute sell trade for ", m_Symbol);
                }
            }
        }
    }

    // 计算止损价格的辅助函数
    double calculateStopLoss(double price, double stopLoss, bool isSell = false)
    {
        if (stopLoss == 0)
            return 0;
        return isSell ? price + stopLoss * _Point : price - stopLoss * _Point;
    }

    // 计算止盈价格

    // 清理
    void ExitTrade() override
    {

        IndicatorRelease(m_RSI.GetHandle());
        IndicatorRelease(m_MA.GetHandle());
        delete m_RSI;
        delete m_MA;
        delete m_Tools;
    };
};
CRSIMA *g_Strategy;

//+------------------------------------------------------------------+
int OnInit()
{
    g_Strategy = new CRSIMA(_Symbol, InpTimeframe, InpBaseMagicNumber, InpRISValue, InpMAValue);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return (INIT_FAILED);
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
    CPerformanceEvaluator::CalculateOutlierRatio();
    CPerformanceEvaluator::CalculateHourlyProfitLoss();
}
