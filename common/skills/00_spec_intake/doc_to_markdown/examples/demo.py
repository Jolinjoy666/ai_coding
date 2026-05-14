#!/usr/bin/env python3
"""
Demo script for doc_to_markdown skill.

This script demonstrates how to use the skill to convert
a sample image or PDF to Markdown format.
"""

import os
import sys
import tempfile
from PIL import Image, ImageDraw, ImageFont

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.main import DocumentProcessor


def create_sample_image():
    """Create a sample image with text for demonstration."""
    # Create a simple image with text
    img = Image.new('RGB', (800, 600), color='white')
    d = ImageDraw.Draw(img)
    
    # Add title
    d.text((50, 50), "Sample Specification Document", fill='black')
    
    # Add content
    lines = [
        "1. Introduction",
        "   This document outlines the requirements for the new system.",
        "",
        "2. Functional Requirements",
        "   - Requirement 1: The system shall process data in real-time",
        "   - Requirement 2: The system shall support multiple users",
        "   - Requirement 3: The system shall provide audit logging",
        "",
        "3. Technical Specifications",
        "   • Performance: < 100ms response time",
        "   • Availability: 99.9% uptime",
        "   • Security: AES-256 encryption",
        "",
        "4. Interface Requirements",
        "   - REST API with JSON payloads",
        "   - WebSocket for real-time updates",
        "   - OAuth 2.0 authentication"
    ]
    
    y = 100
    for line in lines:
        d.text((50, y), line, fill='black')
        y += 20
    
    # Save to temporary file
    temp_file = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    img.save(temp_file.name)
    return temp_file.name


def demo_image_processing():
    """Demonstrate image processing."""
    print("=== Image Processing Demo ===")
    
    # Create sample image
    image_path = create_sample_image()
    print(f"Created sample image: {image_path}")
    
    # Process image
    config = {
        'ocr_engine': 'auto',
        'language': 'en',
        'preserve_layout': True,
        'extract_tables': True
    }
    
    processor = DocumentProcessor(config)
    result = processor.process_file(image_path, 'markdown')
    
    # Display results
    print(f"\nFile: {image_path}")
    print(f"Type: {result['file_type']}")
    print(f"Pages: {result['metadata']['total_pages']}")
    print(f"Method: {result['metadata']['extraction_method']}")
    
    # Show markdown preview
    markdown_text = result.get('markdown_text', '')
    print(f"\nMarkdown Output (first 1000 chars):\n{'='*50}")
    print(markdown_text[:1000])
    if len(markdown_text) > 1000:
        print("... (truncated)")
    
    # Clean up
    os.unlink(image_path)
    
    return result


def demo_pdf_processing():
    """Demonstrate PDF processing."""
    print("\n=== PDF Processing Demo ===")
    
    # Check if there's a sample PDF available
    sample_pdfs = [
        "/home/hp/cfy/chiplet_interconnect_sim/CAM/doc/技术文档.pdf",
        # Add more sample PDFs here
    ]
    
    pdf_path = None
    for path in sample_pdfs:
        if os.path.exists(path):
            pdf_path = path
            break
    
    if not pdf_path:
        print("No sample PDF found. Skipping PDF demo.")
        return None
    
    # Process PDF
    config = {
        'ocr_engine': 'auto',
        'language': 'zh',  # Chinese document
        'preserve_layout': True,
        'extract_tables': True
    }
    
    processor = DocumentProcessor(config)
    result = processor.process_file(pdf_path, 'markdown')
    
    # Display results
    print(f"\nFile: {pdf_path}")
    print(f"Type: {result['file_type']}")
    print(f"Content Type: {result['content_type']}")
    print(f"Pages: {result['metadata']['total_pages']}")
    print(f"Method: {result['metadata']['extraction_method']}")
    
    # Show markdown preview
    markdown_text = result.get('markdown_text', '')
    print(f"\nMarkdown Output (first 1000 chars):\n{'='*50}")
    print(markdown_text[:1000])
    if len(markdown_text) > 1000:
        print("... (truncated)")
    
    return result


def main():
    """Main demo function."""
    print("doc_to_markdown Skill Demo")
    print("="*50)
    
    # Run demos
    image_result = demo_image_processing()
    pdf_result = demo_pdf_processing()
    
    # Summary
    print("\n" + "="*50)
    print("Demo Summary:")
    print("-" * 50)
    
    if image_result:
        print(f"Image processing: ✓ Success")
        print(f"  - Pages: {image_result['metadata']['total_pages']}")
        print(f"  - Method: {image_result['metadata']['extraction_method']}")
    
    if pdf_result:
        print(f"PDF processing: ✓ Success")
        print(f"  - Pages: {pdf_result['metadata']['total_pages']}")
        print(f"  - Method: {pdf_result['metadata']['extraction_method']}")
    
    print("\nThe doc_to_markdown skill is ready for use!")
    print("See USAGE.md for detailed usage instructions.")


if __name__ == '__main__':
    main()