//+------------------------------------------------------------------+
//|                                                  GridStrategy.mq5 |
//|                        Copyright 2025, MetaQuotes Ltd.            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.02"

#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"
#include "include/Draw.mqh"

input group "-----> 网格策略参数";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // 策略周期
input int InpBaseMagicNumber = 5424524;              // 基础魔术号
input double InpLotSize = 0.01;                      // 交易手数
input double InpUpLimit = 160;                       // 价格上限
input double InpDownLimit = 140;                     // 价格下限
input int InpGridCount = 30;                         // 网格层数

class CGrid : public CStrategy
{
private:
    CTools *m_Tools;
    CDraw m_Draw;

    // 网格数据结构
    double m_GridPrices[];  // 网格价格数组
    bool m_IsOrderActive[]; // 订单活跃状态
    int m_Digits;           // 品种小数位数
    double m_Point;         // 品种点值

    // 初始化网格价格
    void InitGrid()
    {
        ArrayResize(m_GridPrices, InpGridCount);
        ArrayResize(m_IsOrderActive, InpGridCount);
        double step = (InpUpLimit - InpDownLimit) / (InpGridCount - 1);
        for (int i = 0; i < InpGridCount; ++i)
        {
            m_GridPrices[i] = InpUpLimit - step * i;
            m_IsOrderActive[i] = true;
        }
    }

    // 获取止损价格
    double GetStopPrice(int level)
    {
        return (level == InpGridCount - 1)
                   ? m_GridPrices[level] - (m_GridPrices[1] - m_GridPrices[0])
                   : m_GridPrices[level + 1];
    }

    // 检查价格是否相同(带精度处理)
    bool IsPriceEqual(double p1, double p2)
    {
        return MathAbs(NormalizeDouble(p1, m_Digits) - NormalizeDouble(p2, m_Digits)) < m_Point * 0.5;
    }

public:
    CGrid(string symbol, ENUM_TIMEFRAMES tf, int magic)
        : CStrategy(symbol, tf, magic)
    {
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        m_Tools = new CTools(symbol, &m_Trade);
        m_Digits = (int)SymbolInfoInteger(m_Symbol, SYMBOL_DIGITS);
        m_Point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
        InitGrid();
    }

    ~CGrid()
    {
        delete m_Tools;
    }

    // 主处理函数
    void OnTick() override
    {
        if (m_Tools.IsNewBar(InpTimeframe))
        {
            ClearExpiredGrids();
            UpdateGridPrices();
        }

        if (!m_Tools.IsNewBar(PERIOD_M1))
            return;

        double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        ProcessOrderPlacement(currentAsk);
        CleanupInactiveOrders();
    }

    void OnDeinit(const int reason)
    {
        m_Tools.CloseAllPositions(m_MagicNumber);
        m_Tools.DeleteAllOrders(m_MagicNumber);
    }

private:
    // 清除过期网格线
    void ClearExpiredGrids()
    {
        for (int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; --i)
        {
            string objName = ObjectName(0, i);
            if (StringFind(objName, "GridLine_") == 0)
                ObjectDelete(0, objName);
        }
    }

    // 更新网格价格状态
    void UpdateGridPrices()
    {
        for (int i = 0; i < InpGridCount; ++i)
        {
            m_IsOrderActive[i] = (m_GridPrices[i] > SymbolInfoDouble(_Symbol, SYMBOL_BID));
        }
    }

    // 处理订单逻辑
    void ProcessOrderPlacement(double currentAsk)
    {
        // 从下往上检查可挂单位置
        for (int i = InpGridCount - 1; i >= 0; --i)
        {
            if (m_IsOrderActive[i] && m_GridPrices[i] > currentAsk)
            {
                PlaceGridOrder(i);
            }
        }
    }

    // 下单操作
    void PlaceGridOrder(int level)
    {
        string comment = "GridOrder_" + IntegerToString(level);
        double price = NormalizeDouble(m_GridPrices[level], m_Digits);
        double sl = NormalizeDouble(GetStopPrice(level), m_Digits);

        if (m_Trade.SellLimit(InpLotSize, price, _Symbol, 0, sl,
                              ORDER_TIME_GTC, 0, comment))
        {
            PrintFormat("挂单成功: 层级 %d, 价格 %.5f, TP %.5f",
                        level, price, sl);
        }
        else
        {
            Print("挂单失败! 错误:", GetLastError());
        }
    }

    // 清理无效订单
    void CleanupInactiveOrders()
    {
        for (int i = 0; i < InpGridCount; ++i)
        {
            if (!m_IsOrderActive[i])
            {
                ulong ticket = FindOrderTicketByLevel(i);
                if (ticket != 0)
                {
                    m_Trade.OrderDelete(ticket);
                    Print("已删除无效订单:", ticket);
                }
            }
        }
    }

    // 根据层级查找订单
    ulong FindOrderTicketByLevel(int level)
    {
        for (int j = OrdersTotal() - 1; j >= 0; --j)
        {
            COrderInfo order;
            if (order.SelectByIndex(j) && order.Symbol() == _Symbol &&
                order.Magic() == m_MagicNumber)
            {
                string comment = order.Comment();
                if (StringFind(comment, "GridOrder_") == 0 &&
                    StringFind(comment, IntegerToString(level)) != -1)
                {
                    return order.Ticket();
                }
            }
        }
        return 0;
    }
};

// 全局策略实例
CGrid *g_pStrategy;

// 初始化函数
int OnInit()
{
    if (InpGridCount < 2)
    {
        Alert("网格数量必须大于1!");
        return (INIT_PARAMETERS_INCORRECT);
    }

    if (InpUpLimit <= InpDownLimit)
    {
        Alert("上限必须大于下限!");
        return (INIT_PARAMETERS_INCORRECT);
    }

    g_pStrategy = new CGrid(_Symbol, InpTimeframe, InpBaseMagicNumber);
    return (INIT_SUCCEEDED);
}

// 主循环
void OnTick()
{
    if (g_pStrategy)
        g_pStrategy.OnTick();
}

// 去初始化
void OnDeinit(const int reason)
{
    if (g_pStrategy)
    {
        g_pStrategy.OnDeinit(reason);
        delete g_pStrategy;
    }
}