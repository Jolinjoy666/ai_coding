# doc_to_markdown Skill Usage Guide

## Overview

The `doc_to_markdown` skill extracts text from images or PDF files and converts it to structured Markdown format. This is particularly useful for processing specification documents that may be provided as images or PDFs.

## Features

- **Multi-format Support**: Handles both images (JPG, PNG, TIFF, BMP, WebP) and PDFs (digital and scanned)
- **Automatic OCR**: Uses OCR engines (Tesseract, EasyOCR, PaddleOCR) for image-based content
- **Layout Preservation**: Maintains document structure including headings, paragraphs, lists, and tables
- **Multiple Output Formats**: Supports Markdown, plain text, and JSON output
- **Configurable**: Adjustable OCR engine, language, and processing options

## Installation

### Prerequisites

1. Python 3.8 or higher
2. Required Python packages (install via pip):
   ```bash
   pip install pytesseract Pillow PyPDF2 pdf2image tabulate
   ```

3. OCR Engine (choose one or more):
   - **Tesseract**: System package required
     ```bash
     # Ubuntu/Debian
     sudo apt-get install tesseract-ocr tesseract-ocr-eng
     
     # macOS
     brew install tesseract
     ```
   - **EasyOCR**: Pure Python, no system dependencies
     ```bash
     pip install easyocr
     ```
   - **PaddleOCR**: Pure Python, good for Chinese text
     ```bash
     pip install paddleocr
     ```

## Usage

### Command Line Interface

```bash
# Basic usage
python scripts/main.py input_file.pdf -o output.md

# With options
python scripts/main.py input_image.png -o output.md -f markdown -l en --ocr-engine easyocr

# Get JSON output
python scripts/main.py document.pdf -o output.json -f json

# Verbose logging
python scripts/main.py input.pdf -o output.md -v
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `input_file` | Input image or PDF file | Required |
| `-o, --output` | Output file path | stdout |
| `-f, --format` | Output format: markdown, plain_text, json | markdown |
| `-l, --language` | Document language | en |
| `--ocr-engine` | OCR engine: auto, tesseract, easyocr, paddleocr | auto |
| `--preserve-layout` | Preserve document layout | True |
| `--extract-tables` | Extract tables separately | True |
| `-v, --verbose` | Verbose logging | False |

### Python API

```python
from scripts.main import DocumentProcessor

# Configuration
config = {
    'ocr_engine': 'auto',  # or 'tesseract', 'easyocr', 'paddleocr'
    'language': 'en',
    'preserve_layout': True,
    'extract_tables': True
}

# Create processor
processor = DocumentProcessor(config)

# Process file
result = processor.process_file('document.pdf', 'markdown')

# Access results
markdown_text = result['markdown_text']
metadata = result['metadata']
print(f"Pages processed: {metadata['total_pages']}")
print(f"Extraction method: {metadata['extraction_method']}")
```

## Supported File Types

### Images
- JPG/JPEG
- PNG
- TIFF/TIF
- BMP
- WebP

### PDFs
- Digital PDFs (text-based)
- Scanned PDFs (image-based)

## Output Formats

### Markdown
- Structured document with headings, paragraphs, lists
- Tables formatted as Markdown tables
- Metadata section with extraction information

### Plain Text
- Raw extracted text without formatting

### JSON
- Structured data with pages, metadata, and confidence scores

## Configuration Options

### OCR Engines

| Engine | Pros | Cons |
|--------|------|------|
| **Tesseract** | Fast, widely supported | Requires system installation |
| **EasyOCR** | Pure Python, good accuracy | Slower, larger model size |
| **PaddleOCR** | Good for Chinese text | Larger model size |

### Language Support

- `en`: English
- `zh`: Chinese
- `ja`: Japanese
- `ko`: Korean
- And many others (see OCR engine documentation)

## Integration with MS-Agent

This skill can be integrated into MS-Agent workflows:

1. **Skill Discovery**: The skill is automatically discovered by MS-Agent's skill loader
2. **Skill Invocation**: Can be invoked via the MS-Agent skill system
3. **Output Usage**: Markdown output can be used by other skills for further processing

### Example MS-Agent Workflow

```yaml
# Example workflow using doc_to_markdown
workflow:
  - skill: doc_to_markdoc_to_markdown
    inputs:
      file_path: "specification.pdf"
      language: "en"
    outputs:
      - markdown_text
      - metadata
  
  - skill: spec_to_requirements
    inputs:
      raw_spec_or_user_request: "{{ markdown_text }}"
    outputs:
      - structured_requirements
```

## Troubleshooting

### Common Issues

1. **No OCR engines available**
   - Install at least one OCR engine (Tesseract, EasyOCR, or PaddleOCR)
   - For Tesseract, ensure system package is installed

2. **Poor OCR accuracy**
   - Try different OCR engines
   - Ensure good image quality (300 DPI recommended)
   - Specify correct language

3. **Memory errors with large PDFs**
   - Process pages individually
   - Use smaller image resolution for OCR

### Debugging

Enable verbose logging for detailed information:
```bash
python scripts/main.py input.pdf -o output.md -v
```

## Performance Tips

1. **Digital PDFs**: Text extraction is fast and accurate
2. **Scanned PDFs**: OCR processing is slower; consider image quality
3. **Large Documents**: Process in batches for better memory management
4. **Language-Specific**: Use appropriate OCR engine for best results

## Examples

See the `examples/` directory for sample scripts and usage patterns.

## License

This skill follows the same license as the parent project.