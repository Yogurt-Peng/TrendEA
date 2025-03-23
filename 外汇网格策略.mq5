#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"

// 基本参数
input group "----->基本参数";
input int InpMagicNumber = 145124;                   // EA编号 (专家交易系统编号)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 周期
input double InpLotSize = 0.01;                      // 交易手数
input int InpGridDistance = 400;                     // 网格间距（以点数为单位）

input int InpEntryDCPeriod = 20; // 入场指标周期

class CGridTrading : public CStrategy
{
private:
    // 添加状态跟踪变量
    CTools *m_Tools;
    CDraw m_Draw;
    int m_PositionSize;
    double m_BuyPrice;
    double m_SellPrice;
    double m_LotSize;
    int m_GridDistance;
    CDonchian *m_DCEntry;

    // 新增成员变量
    ENUM_ORDER_TYPE m_CurrentDirection; // 当前交易方向
    int m_LayerCount;                   // 当前加仓层数（0-3）
    double m_EntryPrice;                // 首次入场均价
    double m_AveragePrice;              // 当前持仓均价

    datetime m_StopLossTimes[]; // 记录止损时间

public:
    CGridTrading(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber,
                 double lotSize, int gridDistance) : CStrategy(symbol, timeFrame, magicNumber),
                                                     m_LayerCount(0),
                                                     m_CurrentDirection(WRONG_VALUE)
    {
        m_SellPrice = 0;
        m_BuyPrice = 0;
        m_LotSize = lotSize;
        m_GridDistance = gridDistance;
        m_DCEntry = new CDonchian(symbol, timeFrame, InpEntryDCPeriod);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    };

    ~CGridTrading() {};

    bool Initialize() override
    {
        if (!m_DCEntry.Initialize())
        {
            Print("Failed to initialize indicators for ", m_Symbol);
            return false;
        }

        ChartIndicatorAdd(0, 0, m_DCEntry.GetHandle());
        return true;
    }

    // 处理加仓逻辑
    void AddLayer()
    {
        if (m_LayerCount >= 3)
            return;

        // 计算加仓价格
        double addPrice = m_AveragePrice - (m_GridDistance * _Point) * (m_LayerCount + 1);
        m_Trade.PositionOpen(m_Symbol, m_CurrentDirection, m_LotSize, addPrice, 0, 0, "加仓");

        // 更新均价和层数
        m_AveragePrice = (m_AveragePrice * (m_LayerCount + 1) + addPrice) / (m_LayerCount + 2);
        m_LayerCount++;
    }

    // 平仓并重置状态
    SignalType TradeSignal() override
    {
        double close1 = iClose(m_Symbol, m_Timeframe, 1);
        double close2 = iClose(m_Symbol, m_Timeframe, 2);

        if (close1 > m_DCEntry.Upper(1) && close2 <= m_DCEntry.Upper(1))
            return SellSignal;
        if (close1 < m_DCEntry.Lower(1) && close2 >= m_DCEntry.Lower(1))
            return BuySignal;
        return NoSignal;
    }

    void OnTick() override
    {
        if (!m_Tools.IsNewBar(PERIOD_M1))
            return;

        // 获取当前持仓状态
        m_PositionSize = m_Tools.GetPositionCount(m_MagicNumber);
        int m_OrderSize = m_Tools.GetOrderCount(m_MagicNumber);

        // 初始挂单逻辑
        if (m_PositionSize == 0 && m_CurrentDirection == WRONG_VALUE)
        {
            double close = iClose(m_Symbol, InpTimeframe, 1);
            double point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // 计算点差
            double spread = ask - bid;

            // 计算动态触发价格
            if (m_BuyPrice == 0)
                m_BuyPrice = close + (m_GridDistance / 2) * point;
            if (m_SellPrice == 0)
                m_SellPrice = close - (m_GridDistance / 2) * point;

            // 市价触发逻辑
            // if (ask >= m_BuyPrice && spread <= 15)
            // {
            //     if (m_Trade.Buy(m_LotSize, m_Symbol, ask, 0, 0, "初始买入"))
            //     {
            //         m_CurrentDirection = ORDER_TYPE_BUY;
            //         m_EntryPrice = ask;
            //         m_AveragePrice = ask;
            //     }
            // }
            // else if (bid <= m_SellPrice && spread <= 15)
            // {
            //     if (m_Trade.Sell(m_LotSize, m_Symbol, bid, 0, 0, "初始卖出"))
            //     {
            //         m_CurrentDirection = ORDER_TYPE_SELL;
            //         m_EntryPrice = bid;
            //         m_AveragePrice = bid;
            //     }
            // }
            SignalType signal = TradeSignal();

            if (signal == BuySignal)
            {
                if (m_Trade.Buy(m_LotSize, m_Symbol, ask, 0, 0, "初始买入"))
                {
                    m_CurrentDirection = ORDER_TYPE_BUY;
                    m_EntryPrice = ask;
                    m_AveragePrice = ask;
                }
            }
            else if (signal == SellSignal)
            {

                if (m_Trade.Sell(m_LotSize, m_Symbol, bid, 0, 0, "初始卖出"))
                {
                    m_CurrentDirection = ORDER_TYPE_SELL;
                    m_EntryPrice = bid;
                    m_AveragePrice = bid;
                }
            }
        }
        // 持仓状态处理
        else if (m_PositionSize > 0)
        {

            double point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
            double profitPoints = m_Tools.GetTotalProfit(m_MagicNumber) * 100;

            // 盈利平仓条件
            if (profitPoints >= m_GridDistance && (m_PositionSize == 1 || m_PositionSize == 2))
            {
                m_Tools.CloseAllPositions(m_MagicNumber);
                m_LayerCount = 0;
                m_CurrentDirection = WRONG_VALUE;
                m_SellPrice = 0;
                m_BuyPrice = 0;
                return;
            }

            if (m_PositionSize == 3)
            {
                if (profitPoints >= 0)
                {
                    m_Tools.CloseAllPositions(m_MagicNumber);
                    m_LayerCount = 0;
                    m_CurrentDirection = WRONG_VALUE;
                    m_SellPrice = 0;
                    m_BuyPrice = 0;
                    return;
                }
                else if (profitPoints <= -m_GridDistance * 6)
                {
                    m_Tools.CloseAllPositions(m_MagicNumber);
                    m_LayerCount = 0;
                    m_CurrentDirection = WRONG_VALUE;
                    m_SellPrice = 0;
                    m_BuyPrice = 0;
                    ArrayResize(m_StopLossTimes, ArraySize(m_StopLossTimes) + 1);
                    m_StopLossTimes[ArraySize(m_StopLossTimes) - 1] = TimeCurrent();
                    return;
                }
            }

            if (m_PositionSize == 1)
            {
                if (profitPoints <= -m_GridDistance)
                {
                    AddLayer();
                }
            }
            if (m_PositionSize == 2)
            {
                if (profitPoints <= -3 * m_GridDistance)
                {
                    AddLayer();
                }
            }
        }
    }

    // 添加时间统计方法
    void PrintStopLossStats()
    {
        int total = ArraySize(m_StopLossTimes);
        Print("===== 6倍网格止损统计 =====");
        Print("总触发次数: ", total);

        for (int i = 0; i < total; i++)
        {
            Print(i + 1, ". ", TimeToString(m_StopLossTimes[i]));
        }
    }
};

CGridTrading *g_Strategy;

//+------------------------------------------------------------------+

int OnInit()
{
    g_Strategy = new CGridTrading(_Symbol, InpTimeframe, InpMagicNumber, InpLotSize, InpGridDistance);
    if (!g_Strategy.Initialize())
    {
        Print("Failed to initialize strategy!");
        return INIT_FAILED;
    }
    EventSetTimer(10); // 设置定时器，每30秒执行一次OnTimer函数
    return INIT_SUCCEEDED;
}

void OnTick()
{
    g_Strategy.OnTick();
}

void OnDeinit(const int reason)
{
    g_Strategy.PrintStopLossStats();
    g_Strategy.OnDeinit(reason);
    delete g_Strategy;
}
