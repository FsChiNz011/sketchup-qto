# BOQ Office - Cost Database Module
# ฐานข้อมูลราคาวัสดุ/ค่าแรงต่อหน่วย แยกตาม Division > Category > Spec
# บันทึกเป็นไฟล์ JSON เก็บไว้ข้าง ๆ ไฟล์โมเดล (หรือโฟลเดอร์ Home ถ้ายังไม่ Save โมเดล)

require 'json'
require 'fileutils'

module BOQOffice
  module CostDatabase

    DB_FILENAME = 'boq_office_costs.json'

    # ----------------------------------------------------------------------
    # โครงสร้างข้อมูลในหน่วยความจำ:
    # {
    #   "STR|Beam|240KSC" => { material: 1800.0, labor: 350.0, updated_at: "..." },
    #   "ARCH|Wall|"       => { material: 320.0,  labor: 120.0, updated_at: "..." }
    # }
    # key = "DIVISION|CATEGORY|SPEC" (SPEC อาจเป็นค่าว่างได้ หมายถึงราคากลางของ Category นั้น)
    # ----------------------------------------------------------------------

    def self.data
      @data ||= load_from_disk
    end

    def self.reload
      @data = load_from_disk
    end

    # คืนค่า key มาตรฐานจาก division/category/spec
    def self.make_key(division, category, spec = '')
      spec = (spec || '').strip
      "#{division}|#{category}|#{spec}"
    end

    # ค้นหาราคา: ถ้ามี spec เฉพาะให้ใช้ก่อน ถ้าไม่พบให้ fallback ไปราคากลางของ Category (spec ว่าง)
    def self.lookup(division, category, spec = '')
      exact = data[make_key(division, category, spec)]
      return exact if exact

      data[make_key(division, category, '')]
    end

    def self.material_price(division, category, spec = '')
      entry = lookup(division, category, spec)
      entry ? entry['material'].to_f : 0.0
    end

    def self.labor_price(division, category, spec = '')
      entry = lookup(division, category, spec)
      entry ? entry['labor'].to_f : 0.0
    end

    def self.unit_price(division, category, spec = '')
      material_price(division, category, spec) + labor_price(division, category, spec)
    end

    # บันทึก/อัปเดตราคา 1 รายการ (ไม่เขียนไฟล์ทันที ใช้ภายในสำหรับ batch operation)
    def self.set_price_in_memory(division, category, spec, material, labor)
      key = make_key(division, category, spec)
      data[key] = {
        'division'   => division,
        'category'   => category,
        'spec'       => (spec || '').strip,
        'material'   => material.to_f,
        'labor'      => labor.to_f,
        'updated_at' => Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }
      data[key]
    end

    # บันทึก/อัปเดตราคา 1 รายการ (เขียนไฟล์ทันที)
    def self.set_price(division, category, spec, material, labor)
      entry = set_price_in_memory(division, category, spec, material, labor)
      save_to_disk
      entry
    end

    def self.delete_price(division, category, spec)
      key = make_key(division, category, spec)
      removed = data.delete(key)
      save_to_disk if removed
      removed
    end

    # คืนค่ารายการทั้งหมดเป็น Array (สำหรับแสดงในตาราง UI)
    def self.all_entries
      data.values.sort_by { |e| [e['division'], e['category'], e['spec']] }
    end

    # ----------------------------------------------------------------------
    # Persistence
    # ----------------------------------------------------------------------

    # path ของไฟล์ฐานข้อมูล: เก็บไว้โฟลเดอร์เดียวกับไฟล์ .skp
    # ถ้ายังไม่เคย Save โมเดล ให้ใช้ Dir.home แทน
    def self.db_path
      model_path = begin
        Sketchup.active_model&.path
      rescue
        nil
      end

      dir = (model_path && !model_path.empty?) ? File.dirname(model_path) : Dir.home
      File.join(dir, DB_FILENAME)
    end

    def self.load_from_disk
      path = db_path
      return {} unless File.exist?(path)

      begin
        raw = File.read(path, encoding: 'UTF-8')
        JSON.parse(raw)
      rescue => e
        UI.messagebox("ไม่สามารถอ่านฐานข้อมูลราคา (#{File.basename(path)})\n#{e.message}\nจะเริ่มฐานข้อมูลใหม่") rescue nil
        {}
      end
    end

    def self.save_to_disk
      path = db_path
      begin
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w', encoding: 'UTF-8') do |f|
          f.write(JSON.pretty_generate(data))
        end
        true
      rescue => e
        UI.messagebox("บันทึกฐานข้อมูลราคาไม่สำเร็จ\n#{e.message}")
        false
      end
    end

    # นำเข้าราคาจากไฟล์ CSV ภายนอก (ลำดับคอลัมน์: division,category,spec,material,labor)
    def self.import_csv(path)
      require 'csv'
      count = 0
      CSV.foreach(path, headers: true, encoding: 'UTF-8') do |row|
        next unless row['division'] && row['category']
        set_price_in_memory(
          row['division'],
          row['category'],
          row['spec'] || '',
          row['material'].to_f,
          row['labor'].to_f
        )
        count += 1
      end
      save_to_disk if count > 0
      count
    end

  end
end
