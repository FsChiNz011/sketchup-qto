# BOQ Office - Factor F Calculator Module
# คำนวณค่า Factor F ตามหนังสือกรมบัญชีกลาง สำหรับงานก่อสร้างอาคาร
# วิธีคำนวณ: Linear Interpolation ระหว่างช่วงค่างานต้นทุน (B-C) และ Factor F (D-E)
#
# อ้างอิงตาราง Factor F งานก่อสร้างอาคาร (ใช้กับค่างานต้นทุนสูงสุด 1,000 ล้านบาท)
# ตารางนี้เป็นค่าอ้างอิงทั่วไป ผู้ใช้ควรตรวจสอบกับประกาศกรมบัญชีกลางฉบับล่าสุดก่อนใช้งานจริง

module BOQOffice
  module FactorFCalculator

    # ตาราง [ค่างานต้นทุนขั้นต่ำ (B), ค่างานต้นทุนขั้นสูง (C), Factor F ที่ B (D), Factor F ที่ C (E)]
    # ค่างานต้นทุนไม่เกิน 500,000 บาท ใช้ Factor F คงที่ = 1.3091 (ไม่ต้องคำนวณ)
    TABLE = [
      { b: 500_000,      c: 1_000_000,    d: 1.3091, e: 1.3067 },
      { b: 1_000_000,    c: 2_000_000,    d: 1.3067, e: 1.2965 },
      { b: 2_000_000,    c: 3_000_000,    d: 1.2965, e: 1.2840 },
      { b: 3_000_000,    c: 5_000_000,    d: 1.2840, e: 1.2615 },
      { b: 5_000_000,    c: 10_000_000,   d: 1.2615, e: 1.2370 },
      { b: 10_000_000,   c: 25_000_000,   d: 1.2370, e: 1.2155 },
      { b: 25_000_000,   c: 50_000_000,   d: 1.2155, e: 1.1940 },
      { b: 50_000_000,   c: 100_000_000,  d: 1.1940, e: 1.1750 },
      { b: 100_000_000,  c: 500_000_000,  d: 1.1750, e: 1.1500 },
      { b: 500_000_000,  c: 1_000_000_000, d: 1.1500, e: 1.1300 }
    ].freeze

    FIXED_THRESHOLD = 500_000
    FIXED_FACTOR    = 1.3091

    # คำนวณ Factor F จากค่างานต้นทุน (A)
    # คืนค่า Hash: { factor:, method:, range: {b:,c:,d:,e:}, steps: {...} }
    def self.calculate(cost_a)
      a = cost_a.to_f

      if a <= FIXED_THRESHOLD
        return {
          factor:    FIXED_FACTOR,
          method:    :fixed,
          a:         a,
          note:      "ค่างานต้นทุนไม่เกิน #{format_money(FIXED_THRESHOLD)} บาท ใช้ Factor F คงที่ = #{FIXED_FACTOR}"
        }
      end

      range = TABLE.find { |r| a > r[:b] && a <= r[:c] }

      if range.nil?
        # เกินช่วงสูงสุดในตาราง - ใช้ค่า Factor F ต่ำสุดเป็นค่าประมาณ และเตือนผู้ใช้
        last = TABLE.last
        return {
          factor: last[:e],
          method: :out_of_range,
          a: a,
          note: "ค่างานต้นทุนเกินช่วงสูงสุดที่รองรับ (#{format_money(last[:c])} บาท) " \
                "กรุณาตรวจสอบกับตารางกรมบัญชีกลางฉบับล่าสุด"
        }
      end

      b, c, d, e = range[:b], range[:c], range[:d], range[:e]

      # สูตร: Factor F = D - { (D-E) x (A-B) / (C-B) }
      diff_de   = (d - e).round(10)
      diff_ab   = a - b
      diff_cb   = c - b
      adjustment = (diff_de * diff_ab / diff_cb)
      factor     = (d - adjustment).round(4)

      {
        factor: factor,
        method: :interpolated,
        a: a,
        range: { b: b, c: c, d: d, e: e },
        steps: {
          diff_de: diff_de,
          diff_ab: diff_ab,
          diff_cb: diff_cb,
          adjustment: adjustment
        },
        note: "ค่างานต้นทุน #{format_money(a)} บาท อยู่ในช่วง #{format_money(b)} - #{format_money(c)} บาท"
      }
    end

    # คำนวณราคากลาง (ค่างานทั้งหมด) จากค่างานต้นทุน
    def self.apply(cost_a)
      result = calculate(cost_a)
      total  = (cost_a.to_f * result[:factor]).round(2)
      result.merge(total: total)
    end

    def self.format_money(amount)
      amount.to_f.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
    end

    # อธิบายขั้นตอนการคำนวณเป็นข้อความ (สำหรับแสดงใน UI / Export)
    def self.explain(result)
      return result[:note] if result[:method] != :interpolated

      r = result[:range]
      s = result[:steps]
      <<~TXT
        A (ค่างานต้นทุน) = #{format_money(result[:a])}
        B (ขั้นต่ำของช่วง) = #{format_money(r[:b])}   C (ขั้นสูงของช่วง) = #{format_money(r[:c])}
        D (Factor F ที่ B) = #{r[:d]}   E (Factor F ที่ C) = #{r[:e]}

        Factor F = D - {(D-E) x (A-B) / (C-B)}
                 = #{r[:d]} - {(#{s[:diff_de]}) x (#{s[:diff_ab].round(2)}) / (#{s[:diff_cb]})}
                 = #{r[:d]} - (#{s[:adjustment].round(6)})
                 = #{result[:factor]}
      TXT
    end

  end
end
