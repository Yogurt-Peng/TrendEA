#include "include/CStrategy.mqh"
#include "include/CIndicators.mqh"
#include "include/CTools.mqh"

input group "---->画线价格提醒策略";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;                                                                                                                                                                                                                      // 1小时周期
input int InpBaseMagicNumber = 542824;                                                                                                                                                                                                                               // 基础魔术号
input string InpSymbols = "XAUUSDm|BTCUSDm|AUDUSDm|EURUSDm|GBPUSDm|NZDUSDm|USDCADm|USDCHFm|USDJPYm|AUDCADm|AUDCHFm|AUDJPYm|AUDNZDm|CADCHFm|CADJPYm|CHFJPYm|EURAUDm|EURCHFm|EURGBPm|EURJPYm|EURNZDm|GBPAUDm|GBPCADm|GBPCHFm|GBPJPYm|GBPNZDm|NZDCADm|NZDCHFm|NZDJPYm"; // 交易品种

class CLinePriceAlert : public CStrategy

{
private:
    CTools *m_Tools;

public:
    CLinePriceAlert(string symbol, ENUM_TIMEFRAMES timeFrame, int magicNumber) : CStrategy(symbol, timeFrame, magicNumber)
    {
        m_Tools = new CTools(symbol, &m_Trade);
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
    }
    ~CLinePriceAlert() {};

    bool Initialize() override
    {
        m_Trade.SetExpertMagicNumber(m_MagicNumber);
        return true;
    }
    void ExecuteTrade() override
    {
        if (!m_Tools.IsNewBar(m_Timeframe))
            return;
    }

    void ExitTrade() override
    {
        printf("ExitTrade\n")
    }
}
