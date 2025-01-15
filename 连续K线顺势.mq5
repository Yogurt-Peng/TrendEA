#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // 1小时周期
input int InpBaseMagicNumber = 542824;          // 基础魔术号
input double InpLotSize = 0.01;                 // 交易手数
input int InpStopLoss = 100;                    // 止损点数 0:不使用
input int InpTakeProfit = 100;                  // 止盈点数 0:不使用
input int InpCanldeSetup = 3;                   // 进场K线数

class CCanldeSetup : public CStrategy
{
private:
    CTools *m_Tools;
    double m_LotSize;
    int m_CanldeSetup;

public:
    CCanldeSetup(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber, double lotSize, int canldeSetup) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_LotSize = lotSize;
        m_CanldeSetup = canldeSetup;
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CCanldeSetup() {};

    // 初始化方法
    bool Initialize() override
    {
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }

    // 自定义信号逻辑
    SignalType TradeSignal() override
    {
        int count = 1;
        while (iClose(m_Symbol, m_Timeframe, count) > iOpen(m_Symbol, m_Timeframe, count) && iClose(m_Symbol, m_Timeframe, count) > iClose(m_Symbol, m_Timeframe, count + 1))
        {
            count++;
        }

        if (count >= m_CanldeSetup)
        {
            return BuySignal;
        }
        count=1;
        while (iClose(m_Symbol, m_Timeframe, count) < iOpen(m_Symbol, m_Timeframe, count) && iClose(m_Symbol, m_Timeframe, count) < iClose(m_Symbol, m_Timeframe, count + 1))
        {
            count++;
        }

        if (count >= m_CanldeSetup)
        {
            return SellSignal;
        }

        return NoSignal;
    }

    // 执行交易
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        SignalType signal = TradeSignal();
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double buySl = (InpStopLoss == 0) ? 0 : ask - InpStopLoss * _Point;
        double buyTp = (InpTakeProfit == 0) ? 0 : ask + InpTakeProfit * _Point;
        double sellSl = (InpStopLoss == 0) ? 0 : bid + InpStopLoss * _Point;
        double sellTp = (InpTakeProfit == 0) ? 0 : bid - InpTakeProfit * _Point;

        if (signal == BuySignal && m_Tools.GetPositionCount(m_MagicNumber,POSITION_TYPE_BUY) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber,POSITION_TYPE_SELL);
            m_Trade.Buy(m_LotSize, m_Symbol, ask, buySl, buyTp);
        }
        else if (signal == SellSignal&& m_Tools.GetPositionCount(m_MagicNumber,POSITION_TYPE_SELL) == 0)
        {
            m_Tools.CloseAllPositions(m_MagicNumber,POSITION_TYPE_BUY);
            m_Trade.Sell(m_LotSize, m_Symbol, bid, sellSl, sellTp);
        }
        
    }
};

CCanldeSetup *g_CanldeSetup = NULL;

//+------------------------------------------------------------------+
int OnInit()
{
    g_CanldeSetup = new CCanldeSetup(_Symbol, InpTimeframe,InpBaseMagicNumber, InpLotSize, InpCanldeSetup);
    if (!g_CanldeSetup.Initialize())
    {
        Print("Failed to initialize strategy for ", _Symbol);
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

void OnTick()
{
    g_CanldeSetup.OnTick();
}

