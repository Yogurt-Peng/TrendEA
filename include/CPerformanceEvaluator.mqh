// PerformanceEvaluator.mqh
#include <Trade/Trade.mqh>
class CPerformanceEvaluator
{
private:
public:
    // 构造函数
    CPerformanceEvaluator() {};
    ~CPerformanceEvaluator() {};

    // 初始化函数
    void Initialize() {};

    // 计算离群值比例
    static void CalculateOutlierRatio()
    {
        HistorySelect(0, TimeCurrent());
        int deals = HistoryDealsTotal();
        double total_profit = 0.0;
        double top_10_profit = 0.0;
        double profits[];

        // 遍历历史订单，提取所有盈利订单的利润
        for (int i = 0; i < deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if (profit > 0) // 仅统计盈利订单
            {
                ArrayResize(profits, ArraySize(profits) + 1);
                profits[ArraySize(profits) - 1] = profit;
                total_profit += profit;
            }
        }

        // 如果没有盈利订单，直接返回
        if (ArraySize(profits) == 0)
        {
            Print("没有盈利订单，无法计算离群值比例。");
            return;
        }

        // 按利润从高到低排序
        ArraySort(profits);

        // 计算前10%的总利润
        int top_10_count = MathMax(1, (int)(ArraySize(profits) * 0.1)); // 至少保留一个
        for (int i = ArraySize(profits) - 1; i >= ArraySize(profits) - top_10_count; i--)
        {
            top_10_profit += profits[i];
        }

        // 计算离群值比例
        double outlier_ratio = (total_profit > 0) ? (top_10_profit / total_profit) : 0.0;

        // 打印结果
        PrintFormat("总利润: %.2f, 前10%%利润: %.2f, 离群值比例: %.2f%%",
                    total_profit, top_10_profit, outlier_ratio * 100);
    };

    // 计算每周的盈利和亏损
    static void CalculateWeeklyProfitAndLoss()
    {
        // 初始化变量
        double weekly_profit[5] = {0.0, 0.0, 0.0, 0.0, 0.0}; // 周一到周五的盈利
        double weekly_loss[5] = {0.0, 0.0, 0.0, 0.0, 0.0};   // 周一到周五的亏损
        HistorySelect(0, TimeCurrent());                     // 选择所有历史记录
        int deals = HistoryDealsTotal();

        // 遍历历史订单
        for (int i = 0; i < deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);

            // 获取订单的利润
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            // 获取订单的成交时间
            datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            MqlDateTime dt_struct;
            TimeToStruct(deal_time, dt_struct); // 转换为日期结构

            // 根据日期结构的 "day_of_week" 判断星期几
            int weekday = dt_struct.day_of_week;
            if (weekday >= 1 && weekday <= 5) // 只统计周一到周五的订单
            {
                if (profit > 0)
                {
                    weekly_profit[weekday - 1] += profit; // 累加盈利
                }
                else if (profit < 0)
                {
                    weekly_loss[weekday - 1] += profit; // 累加亏损
                }
            }
        }

        // 打印结果
        Print("周盈利统计：");
        PrintFormat("周一盈利: %.2f, 周一亏损: %.2f", weekly_profit[0], weekly_loss[0]);
        PrintFormat("周二盈利: %.2f, 周二亏损: %.2f", weekly_profit[1], weekly_loss[1]);
        PrintFormat("周三盈利: %.2f, 周三亏损: %.2f", weekly_profit[2], weekly_loss[2]);
        PrintFormat("周四盈利: %.2f, 周四亏损: %.2f", weekly_profit[3], weekly_loss[3]);
        PrintFormat("周五盈利: %.2f, 周五亏损: %.2f", weekly_profit[4], weekly_loss[4]);
    };

    static void CalculateHourlyProfitLoss()
    {
        // 定义结构存储仓位ID和开仓时间
        struct SPositionInfo
        {
            ulong positionId;
            datetime openTime;
        };
        SPositionInfo positions[];

        // 获取当前时间
        HistorySelect(0, TimeCurrent());
        int totalDeals = HistoryDealsTotal();

        // 第一次遍历：收集所有开仓成交的仓位信息
        for (int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket == 0)
                continue;

            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if (entry == DEAL_ENTRY_IN)
            {
                ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                datetime openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

                // 检查是否已存在该仓位ID
                bool exists = false;
                for (int j = 0; j < ArraySize(positions); j++)
                {
                    if (positions[j].positionId == posId)
                    {
                        exists = true;
                        break;
                    }
                }
                if (!exists)
                {
                    SPositionInfo info;
                    info.positionId = posId;
                    info.openTime = openTime;
                    ArrayResize(positions, ArraySize(positions) + 1);
                    positions[ArraySize(positions) - 1] = info;
                }
            }
        }

        // 初始化小时统计数组
        double hourlyProfit[24] = {0};
        double hourlyLoss[24] = {0};

        // 第二次遍历：处理平仓成交
        for (int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket == 0)
                continue;

            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if (entry == DEAL_ENTRY_OUT)
            {
                ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                datetime openTime = 0;

                // 查找对应仓位ID的开仓时间
                for (int j = 0; j < ArraySize(positions); j++)
                {
                    if (positions[j].positionId == posId)
                    {
                        openTime = positions[j].openTime;
                        break;
                    }
                }

                if (openTime > 0)
                {
                    MqlDateTime timeStruct;
                    TimeToStruct(openTime, timeStruct);
                    int hour = timeStruct.hour;

                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    if (profit > 0)
                    {
                        hourlyProfit[hour] += profit;
                    }
                    else if (profit < 0)
                    {
                        hourlyLoss[hour] += -profit; // 亏损记录为正值
                    }
                }
            }
        }

        // 打印统计结果
        Print("每小时开仓的盈利/亏损统计：");
        for (int hour = 0; hour < 24; hour++)
        {
            PrintFormat("%02d:00-%02d:59  盈利: %.2f  亏损: %.2f",
                        hour, hour, hourlyProfit[hour], hourlyLoss[hour]);
        }
    }
};