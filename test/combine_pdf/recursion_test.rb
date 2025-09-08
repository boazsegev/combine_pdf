#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'combine_pdf'

class RecursionTest < Minitest::Test
  def test_recursion_bug_pdf_loads_without_stack_overflow
    # Test that the recursion_bug.pdf file loads without throwing SystemStackError
    # This test verifies the fix for GitHub issue #242

    recursion_pdf_path = File.join(__dir__, '..', 'fixtures', 'recursion_bug.pdf')

    # Verify the test file exists
    assert File.exist?(recursion_pdf_path), "Test fixture recursion_bug.pdf not found at #{recursion_pdf_path}"

    # This should NOT raise SystemStackError: stack level too deep
    # Before the fix, this would cause infinite recursion in HASH_UPDATE_PROC_FOR_OLD
    pdf = nil

    # Use begin/rescue to catch SystemStackError specifically
    begin
      pdf = CombinePDF.load(recursion_pdf_path)
    rescue SystemStackError => e
      flunk("Loading recursion_bug.pdf caused stack overflow: #{e.message}")
    end

    # Verify we got a valid PDF object
    assert_instance_of(CombinePDF::PDF, pdf, "Should return a valid PDF object")

    # Verify the PDF has some content (basic sanity check)
    assert pdf.pages.length > 0, "PDF should have at least one page"
  end

  def test_recursion_bug_pdf_resources_are_properly_handled
    # Additional test to verify that Resources with circular references are handled correctly
    recursion_pdf_path = File.join(__dir__, '..', 'fixtures', 'recursion_bug.pdf')

    pdf = CombinePDF.load(recursion_pdf_path)

    # Verify that the PDF can be processed without issues
    # This tests the catalog_pages method which was the source of the recursion
    begin
      pdf.pages.each do |page|
        # Access page resources to trigger the resource merging logic
        resources = page[:Resources]
        assert resources.is_a?(Hash), "Page resources should be a Hash" if resources
      end
    rescue SystemStackError => e
      flunk("Processing PDF pages caused stack overflow: #{e.message}")
    end
  end
end
