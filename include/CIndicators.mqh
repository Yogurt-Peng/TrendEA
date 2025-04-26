
class CIndicator
{
protected:
    int m_handle;                // 指示器句柄
    string m_symbol;             // 指示器符号
    ENUM_TIMEFRAMES m_timeFrame; // 指示器时间框架

    // 创建指示器句柄的纯虚函数
    virtual int CreateHandle() = 0;
    // 设置缓冲区的虚函数，默认为空实现
    virtual void SetupBuffers() {};

public:
    // 构造函数，初始化指示器符号和时间框架
    CIndicator(string symbol, ENUM_TIMEFRAMES timeFrame)
        : m_handle(INVALID_HANDLE), m_symbol(symbol), m_timeFrame(timeFrame) {}

    // 析构函数，释放指示器句柄
    virtual ~CIndicator()
    {
        if (m_handle != INVALID_HANDLE)
            IndicatorRelease(m_handle);
    }

    // 初始化指示器，创建句柄并设置缓冲区
    bool Initialize()
    {
        m_handle = CreateHandle();
        if (m_handle != INVALID_HANDLE)
        {
            SetupBuffers();
            return true;
        }
        Print("Failed to create handle for ", GetName());
        return false;
    }

    // 获取指示器名称的纯虚函数
    virtual string GetName() const = 0;
    // 获取指示器句柄
    int GetHandle() const { return m_handle; }

    // 获取指定索引和缓冲区的值
    double GetValue(int index, int bufferIndex = 0, int count = 1)
    {
        double buffer[];
        ArraySetAsSeries(buffer, true);
        if (CopyBuffer(m_handle, bufferIndex, index, count, buffer) > 0)
            return buffer[0];
        return 0.0;
    }

    // 获取指定缓冲区、起始索引和计数的值
    bool GetValues(int bufferIndex, int start, int count, double &result[])
    {
        ArraySetAsSeries(result, true);
        return CopyBuffer(m_handle, bufferIndex, start, count, result) == count;
    }
};

class CRSI : public CIndicator
{
protected:
    int m_period;
    ENUM_APPLIED_PRICE m_applied;

    int CreateHandle()
    {
        return iRSI(m_symbol, m_timeFrame, m_period, m_applied);
    }

public:
    CRSI(string symbol, ENUM_TIMEFRAMES tf, int period,
         ENUM_APPLIED_PRICE applied = PRICE_CLOSE)
        : CIndicator(symbol, tf), m_period(period), m_applied(applied) {}

    string GetName() const { return "RSI"; }
};

//+------------------------------------------------------------------+
//|                                                     Bollinger    |
//+------------------------------------------------------------------+
class CBollinger : public CIndicator
{
    int m_period;
    double m_deviation;
    int m_shift;

protected:
    int CreateHandle()
    {
        return iBands(m_symbol, m_timeFrame, m_period,
                      m_shift, m_deviation, PRICE_CLOSE);
    }

public:
    CBollinger(string symbol, ENUM_TIMEFRAMES tf, int period,
               double dev, int shift = 0)
        : CIndicator(symbol, tf), m_period(period),
          m_deviation(dev), m_shift(shift) {}

    string GetName() const { return "Bollinger"; }

    double Upper(int index) { return GetValue(index, 1); }
    double Middle(int index) { return GetValue(index, 0); }
    double Lower(int index) { return GetValue(index, 2); }
};

//+------------------------------------------------------------------+
//|                                                           MA     |
//+------------------------------------------------------------------+
/**
 * @class CMA
 * @brief CMA类用于计算移动平均线（Moving Average）指标。
 *
 * CMA类继承自CIndicator类，用于计算和返回移动平均线指标。该类支持多种移动平均方法，包括简单移动平均（SMA）、指数移动平均（EMA）等。
 *
 * 核心功能：
 * - 计算移动平均线指标
 * - 支持多种移动平均方法
 * - 支持不同的应用价格
 *
 * 使用示例：
 * @code
 * CMA ma("AAPL", ENUM_TIMEFRAMES::DAILY, 50, ENUM_MA_METHOD::EMA);
 * @endcode
 *
 * 构造函数参数：
 * - symbol: 股票代码或交易品种
 * - tf: 时间框架，例如日、周、月等
 * - period: 移动平均线的周期
 * - method: 移动平均方法，例如简单移动平均（SMA）、指数移动平均（EMA）等
 * - shift: 移动平均线的偏移量，默认为0
 * - applied: 应用价格，例如收盘价、开盘价等，默认为收盘价
 *
 * 注意事项：
 * - 构造函数中的参数必须符合相应的类型和范围要求
 * - 使用该类时，需要确保已经正确初始化了CIndicator基类
 */
class CMA : public CIndicator
{
    // 移动平均线周期
    int m_period;
    // 移动平均线方法
    ENUM_MA_METHOD m_method;
    // 移动平均线位移
    int m_shift;
    // 移动平均线应用价格
    ENUM_APPLIED_PRICE m_applied;

protected:
    // 创建移动平均线句柄
    int CreateHandle()
    {
        return iMA(m_symbol, m_timeFrame, m_period,
                   m_shift, m_method, m_applied);
    }

public:
    // 构造函数
    CMA(string symbol, ENUM_TIMEFRAMES tf, int period,
        ENUM_MA_METHOD method, int shift = 0,
        ENUM_APPLIED_PRICE applied = PRICE_CLOSE)
        : CIndicator(symbol, tf), m_period(period),
          m_method(method), m_shift(shift), m_applied(applied) {}

    // 获取指标名称
    string GetName() const { return "MA"; }
};

//+------------------------------------------------------------------+
//|                                                     Heiken Ashi  |
//+------------------------------------------------------------------+
class CHeikenAshi : public CIndicator
{
    double m_open[], m_high[], m_low[], m_close[];

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Examples\\Heiken_Ashi");
    }

    void SetupBuffers()
    {
        ArraySetAsSeries(m_open, true);
        ArraySetAsSeries(m_high, true);
        ArraySetAsSeries(m_low, true);
        ArraySetAsSeries(m_close, true);
    }

public:
    CHeikenAshi(string symbol, ENUM_TIMEFRAMES tf)
        : CIndicator(symbol, tf) {}

    string GetName() const { return "HeikenAshi"; }

    void Refresh(int count = 100)
    {
        CopyBuffer(m_handle, 0, 0, count, m_open);
        CopyBuffer(m_handle, 1, 0, count, m_high);
        CopyBuffer(m_handle, 2, 0, count, m_low);
        CopyBuffer(m_handle, 3, 0, count, m_close);
    }

    double Open(int index) const { return m_open[index]; }
    double High(int index) const { return m_high[index]; }
    double Low(int index) const { return m_low[index]; }
    double Close(int index) const { return m_close[index]; }
};

// ha.Refresh(100);  // 参数表示要获取的数据数量
// // 4. 获取最新价格数据
// double currentHA_Open  = ha.Open(0);   // 最新Heiken Ashi开盘价
// double currentHA_High  = ha.High(0);   // 最新Heiken Ashi最高价
// double currentHA_Low   = ha.Low(0);    // 最新Heiken Ashi最低价
// double currentHA_Close = ha.Close(0);  // 最新Heiken Ashi收盘价
// // 5. 获取历史数据（前一根K线）
// double prevHA_Open  = ha.Open(1);
// double prevHA_Close = ha.Close(1);

//+------------------------------------------------------------------+
//|                                                          ATR     |
//+------------------------------------------------------------------+
class CATR : public CIndicator
{
    int m_period;

protected:
    int CreateHandle()
    {
        return iATR(m_symbol, m_timeFrame, m_period);
    }

public:
    CATR(string symbol, ENUM_TIMEFRAMES tf, int period)
        : CIndicator(symbol, tf), m_period(period) {}

    string GetName() const { return "ATR"; }
};

//+------------------------------------------------------------------+
//|                                                          MFI     |
//+------------------------------------------------------------------+
class CMFI : public CIndicator
{
    int m_period;
    ENUM_APPLIED_VOLUME m_volumeType;

protected:
    int CreateHandle()
    {
        return iMFI(m_symbol, m_timeFrame, m_period, m_volumeType);
    }

public:
    CMFI(string symbol, ENUM_TIMEFRAMES tf, int period,
         ENUM_APPLIED_VOLUME volumeType = VOLUME_TICK)
        : CIndicator(symbol, tf), m_period(period), m_volumeType(volumeType) {}

    string GetName() const { return "MFI"; }
};

//+------------------------------------------------------------------+
//|                                                      MACD        |
//+------------------------------------------------------------------+
class CMACD : public CIndicator
{
    int m_fast;
    int m_slow;
    int m_signal;

protected:
    int CreateHandle()
    {
        return iMACD(m_symbol, m_timeFrame, m_fast, m_slow, m_signal, PRICE_CLOSE);
    }

public:
    CMACD(string symbol, ENUM_TIMEFRAMES tf, int fast, int slow, int signal)
        : CIndicator(symbol, tf), m_fast(fast), m_slow(slow), m_signal(signal) {}

    string GetName() const { return "MACD"; }

    double Main(int index) { return GetValue(0, index); }
    double Signal(int index) { return GetValue(1, index); }
    double Histogram(int index) { return Main(index) - Signal(index); }
};

//+------------------------------------------------------------------+
//|                                                     Donchian     |
//+------------------------------------------------------------------+
class CDonchian : public CIndicator
{
    int m_period;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\donchian_channel", m_period);
    }

public:
    CDonchian(string symbol, ENUM_TIMEFRAMES tf, int period)
        : CIndicator(symbol, tf), m_period(period) {}

    string GetName() const { return "Donchian"; }

    double Upper(int index) { return GetValue(index, 0); }
    double Lower(int index) { return GetValue(index, 1); }
};

//+------------------------------------------------------------------+
//|                                                      ALMA        |
//+------------------------------------------------------------------+
class CALMA : public CIndicator
{
    int m_period;
    double m_sigma;
    double m_offset;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\alma_v2",
                       m_timeFrame, PRICE_CLOSE, m_period, m_sigma, m_offset);
    }

public:
    CALMA(string symbol, ENUM_TIMEFRAMES tf, int period,
          double sigma = 6.0, double offset = 0.85)
        : CIndicator(symbol, tf), m_period(period),
          m_sigma(sigma), m_offset(offset) {}

    string GetName() const { return "ALMA"; }
};

//+------------------------------------------------------------------+
//|                                                      KAMA        |
//+------------------------------------------------------------------+
class CKAMA : public CIndicator
{
    int m_period;
    int m_fast;
    int m_slow;

protected:
    int CreateHandle()
    {
        return iAMA(m_symbol, m_timeFrame, m_period, m_fast, m_slow, 0, PRICE_CLOSE);
    }

public:
    CKAMA(string symbol, ENUM_TIMEFRAMES tf, int period,
          int fast = 2, int slow = 30)
        : CIndicator(symbol, tf), m_period(period),
          m_fast(fast), m_slow(slow) {}

    string GetName() const { return "KAMA"; }
};

//+------------------------------------------------------------------+
//|                                                      Pivot       |
//+------------------------------------------------------------------+
class CPivot : public CIndicator
{
    ENUM_TIMEFRAMES m_baseTF;
    int m_mode;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Wait_Indicators\\All Pivot Points",
                       m_baseTF, m_mode);
    }

public:
    CPivot(string symbol, ENUM_TIMEFRAMES tf,
           ENUM_TIMEFRAMES baseTF = PERIOD_D1, int mode = 0)
        : CIndicator(symbol, tf), m_baseTF(baseTF), m_mode(mode) {}

    string GetName() const { return "Pivot"; }

    double R3(int index) { return GetValue(0, index); }
    double R2(int index) { return GetValue(1, index); }
    double R1(int index) { return GetValue(2, index); }
    double P(int index) { return GetValue(3, index); }
    double S1(int index) { return GetValue(4, index); }
    double S2(int index) { return GetValue(5, index); }
    double S3(int index) { return GetValue(6, index); }
};

//+------------------------------------------------------------------+
//|                                                      WilliamsR  |
//+------------------------------------------------------------------+
class CWilliamsR : public CIndicator
{
protected:
    int m_period; // 通常为14周期

    int CreateHandle()
    {
        return iWPR(m_symbol, m_timeFrame, m_period);
    }

public:
    CWilliamsR(string symbol, ENUM_TIMEFRAMES tf, int period = 14)
        : CIndicator(symbol, tf), m_period(period) {}

    string GetName() const { return "Williams%R"; }

    // 专用访问方法
    double ValueAt(int index)
    {
        return GetValue(0, index); // 威廉指标只有1个缓冲区
    }

    // 判断超买超卖
    bool IsOverbought(int index) { return ValueAt(index) > -20.0; } // 常规超买阈值
    bool IsOversold(int index) { return ValueAt(index) < -80.0; }   // 常规超卖阈值
};

class CZigzag : public CIndicator
{
private:
    int m_Depth;
    int m_Deviation;
    int m_BackStep;

protected:
    int CreateHandle()
    {
        return iCustom(m_symbol, m_timeFrame, "Examples\\ZigzagColor", m_Depth, m_Deviation, m_BackStep);
    };

public:
    CZigzag(string symbol, ENUM_TIMEFRAMES tf, int depth = 10, int deviation = 5, int backstep = 3)
        : CIndicator(symbol, tf), m_Depth(depth), m_Deviation(deviation), m_BackStep(backstep) {};

    ~CZigzag() {};

    string GetName() const { return "Zigzag"; };
};