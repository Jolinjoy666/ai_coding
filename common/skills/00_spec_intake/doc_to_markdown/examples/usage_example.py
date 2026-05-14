#!/usr/bin/env python3
"""
Example usage of the doc_to_markdown skill.

This script demonstrates how to use the DocumentProcessor class
to convert images and PDFs to Markdown format.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.main import DocumentProcessor

def example_image_processing():
    """Example: Process an image file."""
    print("=== Example: Image Processing ===")
    
    # Configuration
    config = {
        'ocr_engine': 'auto',  # Will try tesseract first, then easyocr
        'language': 'en',
        'preserve_layout': True,
        'extract_tables': True
    }
    
    # Create processor
    processor = DocumentProcessor(config)
    
    # Process image
    image_path = "path/to/your/image.png"  # Replace with actual path
    
    if os.path.exists(image_path):
        result = processor.process_file(image_path, 'markdown')
        
        print(f"File: {image_path}")
        print(f"Type: {result['file_type']}")
        print(f"Pages: {result['metadata']['total_pages']}")
        print(f"Method: {result['metadata']['extraction_method']}")
        
        # Print first 500 characters of markdown
        markdown_text = result.get('markdown_text', '')
        print(f"\nMarkdown Preview (first 500 chars):\n{markdown_text[:500]}...")
        
        # Save to file
        output_path = "output.md"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(markdown_text)
        print(f"\nFull output saved to: {output_path}")
    else:
        print(f"Image file not found: {image_path}")

def example_pdf_processing():
    """Example: Process a PDF file."""
    print("\n=== Example: PDF Processing ===")
    
    # Configuration
    config = {
        'ocr_engine': 'auto',
        'language': 'en',
        'preserve_layout': True,
        'extract_tables': True
    }
    
    # Create processor
    processor = DocumentProcessor(config)
    
    # Process PDF
    pdf_path = "path/to/your/document.pdf"  # Replace with actual path
    
    if os.path.exists(pdf_path):
        result = processor.process_file(pdf_path, 'markdown')
        
        print(f"File: {pdf_path}")
        print(f"Type: {result['file_type']}")
        print(f"Content Type: {result['content_type']}")
        print(f"Pages: {result['metadata']['total_pages']}")
        print(f"Method: {result['metadata']['extraction_method']}")
        
        # Print first 500 characters of markdown
        markdown_text = result.get('markdown_text', '')
        print(f"\nMarkdown Preview (first 500 chars):\n{markdown_text[:500]}...")
        
        # Save to file
        output_path = "output.md"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(markdown_text)
        print(f"\nFull output saved to: {output_path}")
    else:
        print(f"PDF file not found: {pdf_path}")

def example_json_output():
    """Example: Get JSON output."""
    print("\n=== Example: JSON Output ===")
    
    # Configuration
    config = {
        'ocr_engine': 'easyocr',  # Use specific engine
        'language': 'en',
        'preserve_layout': True,
        'extract_tables': True
    }
    
    # Create processor
    processor = DocumentProcessor(config)
    
    # Process file
    file_path = "path/to/your/file.pdf"  # Replace with actual path
    
    if os.path.exists(file_path):
        result = processor.process_file(file_path, 'json')
        
        import json
        print(f"File: {file_path}")
        print(f"JSON output keys: {list(result.keys())}")
        
        # Save JSON
        output_path = "output.json"
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"JSON output saved to: {output_path}")
    else:
        print(f"File not found: {file_path}")

if __name__ == '__main__':
    print("doc_to_markdown skill usage examples")
    print("Note: Update file paths in the examples before running")
    
    # Uncomment the examples you want to run:
    # example_image_processing()
    # example_pdf_processing()
    # example_json_output()