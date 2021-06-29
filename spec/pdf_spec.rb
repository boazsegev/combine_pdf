require 'spec_helper'

describe CombinePDF::PDF do

  let(:file1) { stage_out_data_file(short_name: "day.pdf") }
  let(:file2) { stage_out_data_file(short_name: "night.pdf") }
  let(:output_file) { make_tmp_path(short_name: "day_and_night.pdf") }

  before(:each) do
    prune_tmp_folder
  end

  it 'creates output file' do
    pdf = described_class.new
    pdf << CombinePDF.load(file1)
    pdf << CombinePDF.load(file2)
    expect {
      pdf.save(output_file)
    }.to change {
      File.exist?(output_file)
    }.to(true)
  end
end
