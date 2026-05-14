# doc_to_markdown

## Purpose

Extract text from images or PDF files and convert to structured Markdown format. This skill is essential for processing specification documents that may be provided as images or PDFs, enabling downstream AI workflows to work with structured text.

## When to use

Use this skill when:
- Receiving specification documents as images (JPG, PNG, TIFF, BMP) or PDF files.
- Need to convert scanned documents to editable text.
- Extracting text from digital PDFs while preserving structure.
- Processing technical documents with tables, code snippets, or complex layouts.
- Preparing documents for further analysis by other AI skills.

## Inputs

- **file_path** (required): Path to the input image or PDF file.
- **output_format** (optional): Output format, default is "markdown". Options: "markdown", "plain_text", "json".
- **language** (optional): Document language for OCR optimization. Default: "en". Options: "en", "zh", "ja", "ko", etc.
- **preserve_layout** (optional): Whether to preserve document layout. Default: true.
- **extract_tables** (optional): Whether to extract tables separately. Default: true.
- **ocr_engine** (optional): OCR engine to use. Default: "auto". Options: "tesseract", "easyocr", "paddleocr", "auto".

## Outputs

- **markdown_text**: Extracted text in Markdown format.
- **extraction_metadata**: Metadata about the extraction process (pages processed, confidence scores, etc.).
- **table_data**: Extracted tables in structured format (if extract_tables is true).
- **confidence_scores**: Confidence scores for extracted text.
- **processing_log**: Detailed log of processing steps.

## Processing Pipeline

1. **File Type Detection**: Identify whether input is image or PDF.
2. **PDF Processing**:
   - For digital PDFs: Extract text directly using PDF libraries.
   - For scanned PDFs: Convert to images and apply OCR.
3. **Image Processing**:
   - Apply OCR using selected engine.
   - Perform layout analysis to identify document structure.
4. **Structure Analysis**:
   - Detect headings, paragraphs, lists, tables, code blocks.
   - Identify document hierarchy and formatting.
5. **Markdown Generation**:
   - Convert extracted text to Markdown format.
   - Preserve document structure and formatting.
   - Format tables as Markdown tables.
6. **Quality Validation**:
   - Verify Markdown validity.
   - Check extraction confidence.
   - Validate table formatting.

## Supported File Types

- **Images**: JPG, JPEG, PNG, TIFF, BMP, WebP
- **PDFs**: Both digital and scanned PDFs

## Default Configuration

```yaml
ocr_engine: auto
language: en
preserve_layout: true
extract_tables: true
output_format: markdown
```

## Rules

- Always validate input file exists and is readable before processing.
- Preserve original document structure as much as possible.
- For multi-page documents, maintain page order and separation.
- Provide confidence scores for quality assessment.
- Handle errors gracefully and provide informative error messages.
- Log all processing steps for debugging and auditing.