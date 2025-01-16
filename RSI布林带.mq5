#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "==============基本参数==============";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 1小时周期
input int InpBaseMagicNumber = 42451;                // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input int InpStopLoss = 400;                         // 止损点数 0:不使用
input int InpTakeProfit = 0;                         // 止盈点数 0:不使用
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

        double ask = SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_Symbol, SYMBOL_BID);




        if (m_Tools.GetPositionCount(m_MagicNumber) > 0)
        {
            // TradeManagement();
            if (ask >= m_BB.GetValue(1, 0))
            {
                m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_BUY);
            }
            if (bid <= m_BB.GetValue(2, 0))
            {
                m_Tools.CloseAllPositions(m_MagicNumber, POSITION_TYPE_SELL);
            }
        }

        if (!m_Tools.IsNewBar(m_Timeframe))
            return;

        // m_Tools.ApplyTrailingStopByHighLow(10, m_MagicNumber);

        SignalType signal = TradeSignal();
        double buySl = (InpStopLoss == 0) ? 0 : ask - InpStopLoss * _Point;
        double buyTp = (InpTakeProfit == 0) ? 0 : ask + InpTakeProfit * _Point;
        double sellSl = (InpStopLoss == 0) ? 0 : bid + InpStopLoss * _Point;
        double sellTp = (InpTakeProfit == 0) ? 0 : bid - InpTakeProfit * _Point;

        int postionCount = m_Tools.GetPositionCount(m_MagicNumber);

        if (signal == BuySignal && postionCount == 0)
        {
            m_Trade.Buy(InpLotSize, m_Symbol, ask, buySl, buyTp);
        }
        else if (signal == SellSignal && postionCount == 0)
        {
            m_Trade.Sell(InpLotSize, m_Symbol, bid, sellSl, sellTp);
        }
    };

    // 清理
    void ExitTrade() override
    {

        IndicatorRelease(m_RSI.GetHandle());
        IndicatorRelease(m_BB.GetHandle());
        delete m_RSI;
        delete m_BB;
        delete m_Tools;
    };

    // 当多头开仓价格高于布林带上轨时，平仓 当空头开仓价格低于布林带下轨时，平仓
    void TradeManagement()
    {
        CPositionInfo m_positionInfo;
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if (m_positionInfo.SelectByIndex(i) && m_positionInfo.Magic() == m_MagicNumber && m_positionInfo.Symbol() == m_Symbol)
            {

                ulong tick = m_positionInfo.Ticket();
                long type = m_positionInfo.PositionType();
                double Pos_Open = m_positionInfo.PriceOpen();
                double Pos_Curr = m_positionInfo.PriceCurrent();
                double Pos_TP = m_positionInfo.TakeProfit();
                double Pos_SL = m_positionInfo.StopLoss();

                if (type == POSITION_TYPE_BUY)
                {
                    if (Pos_Open >= m_BB.GetValue(1, 0))
                    {
                        if (!m_Trade.PositionClose(m_positionInfo.Ticket()))
                        {
                            Print(m_Symbol, "|", m_MagicNumber, " 平仓失败, Return code=", m_Trade.ResultRetcode(),
                                  ". Code description: ", m_Trade.ResultRetcodeDescription());
                        }
                    }
                }
                else if (type == POSITION_TYPE_SELL)
                {
                    if (Pos_Open <= m_BB.GetValue(2, 0))
                    {
                        if (!m_Trade.PositionClose(m_positionInfo.Ticket()))
                        {
                            Print(m_Symbol, "|", m_MagicNumber, " 平仓失败, Return code=", m_Trade.ResultRetcode(),
                                  ". Code description: ", m_Trade.ResultRetcodeDescription());
                        }
                    }
                }
            }
        }
    };
};
CRSIBollingerBands *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{
    g_Strategy = new CRSIBollingerBands(_Symbol, InpTimeframe, InpBaseMagicNumber, InpRISValue, InpBBValue, InpBBDeviation);
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
