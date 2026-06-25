# BOQ Office - Project Settings Module
# เก็บข้อมูลโครงการ (ชื่อ, สถานที่, หน่วยงาน, ผู้คำนวณ) ใช้ร่วมกันในทุกฟอร์ม
# บันทึกเป็นไฟล์ JSON ข้างไฟล์โมเดล เหมือน Cost Database

require 'json'
require 'fileutils'

module BOQOffice
  module ProjectSettings

    SETTINGS_FILENAME = 'boq_office_settings.json'

    DEFAULTS = {
      'project_name'   => '',
      'location'       => '',
      'owner_org'      => '',
      'drawing_no'     => '',
      'calculated_by'  => '',
      'price_ref'      => '', # อ้างอิงราคาวัสดุ เช่น "ราคาเฉลี่ยวัสดุก่อสร้าง จังหวัด... เดือน..."
      'committee'      => []  # รายชื่อคณะกรรมการกำหนดราคากลาง [{name:, position:}]
    }.freeze

    def self.data
      @data ||= load_from_disk
    end

    def self.reload
      @data = load_from_disk
    end

    def self.get(key)
      data[key.to_s]
    end

    def self.update(hash)
      hash.each { |k, v| data[k.to_s] = v }
      save_to_disk
      data
    end

    def self.settings_path
      model_path = begin
        Sketchup.active_model&.path
      rescue
        nil
      end

      dir = (model_path && !model_path.empty?) ? File.dirname(model_path) : Dir.home
      File.join(dir, SETTINGS_FILENAME)
    end

    def self.load_from_disk
      path = settings_path
      return DEFAULTS.dup unless File.exist?(path)

      begin
        raw = File.read(path, encoding: 'UTF-8')
        loaded = JSON.parse(raw)
        DEFAULTS.merge(loaded)
      rescue => e
        UI.messagebox("ไม่สามารถอ่านการตั้งค่าโครงการ\n#{e.message}\nจะใช้ค่าเริ่มต้น") rescue nil
        DEFAULTS.dup
      end
    end

    def self.save_to_disk
      path = settings_path
      begin
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w', encoding: 'UTF-8') { |f| f.write(JSON.pretty_generate(data)) }
        true
      rescue => e
        UI.messagebox("บันทึกการตั้งค่าโครงการไม่สำเร็จ\n#{e.message}")
        false
      end
    end

    # ชื่อโครงการ - fallback ไปใช้ชื่อไฟล์โมเดลถ้ายังไม่ได้กรอก
    def self.project_name
      name = get('project_name')
      return name unless name.nil? || name.empty?

      begin
        n = Sketchup.active_model&.name
        (n.nil? || n.empty?) ? '(ยังไม่ได้กำหนดชื่อโครงการ)' : n
      rescue
        '(ยังไม่ได้กำหนดชื่อโครงการ)'
      end
    end

  end
end
