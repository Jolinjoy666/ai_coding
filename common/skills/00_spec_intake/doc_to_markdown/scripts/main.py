#!/usr/bin/env python3
"""
Document to Markdown Converter

Extracts text from images or PDF files and converts to structured Markdown format.
Supports both digital and scanned PDFs, with automatic OCR for image-based content.
"""

import os
import sys
import json
import logging
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import tempfile
import subprocess

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DocumentProcessor:
    """Main class for document processing and conversion."""
    
    def __init__(self, config: Optional[Dict] = None):
        """Initialize the processor with configuration."""
        self.config = config or {}
        self.ocr_engine = self.config.get('ocr_engine', 'auto')
        self.language = self.config.get('language', 'en')
        self.preserve_layout = self.config.get('preserve_layout', True)
        self.extract_tables = self.config.get('extract_tables', True)
        
        # Initialize OCR engines
        self._init_ocr_engines()
    
    def _init_ocr_engines(self):
        """Initialize available OCR engines."""
        self.available_engines = []
        
        # Try to initialize Tesseract
        try:
            import pytesseract
            self.tesseract = pytesseract
            self.available_engines.append('tesseract')
            logger.info("Tesseract OCR engine available")
        except ImportError:
            logger.warning("Tesseract not available")
        
        # Try to initialize EasyOCR
        try:
            import easyocr
            self.easyocr = easyocr
            self.available_engines.append('easyocr')
            logger.info("EasyOCR engine available")
        except ImportError:
            logger.warning("EasyOCR not available")
        
        # Try to initialize PaddleOCR
        try:
            from paddleocr import PaddleOCR
            self.paddleocr = PaddleOCR
            self.available_engines.append('paddleocr')
            logger.info("PaddleOCR engine available")
        except ImportError:
            logger.warning("PaddleOCR not available")
        
        if not self.available_engines:
            logger.error("No OCR engines available")
            raise RuntimeError("No OCR engines available. Please install at least one OCR engine.")
    
    def process_file(self, file_path: str, output_format: str = 'markdown') -> Dict[str, Any]:
        """Process a file and return extracted content."""
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        logger.info(f"Processing file: {file_path}")
        
        # Detect file type
        file_type = self._detect_file_type(file_path)
        logger.info(f"Detected file type: {file_type}")
        
        # Process based on file type
        if file_type == 'pdf':
            result = self._process_pdf(file_path)
        elif file_type == 'image':
            result = self._process_image(file_path)
        else:
            raise ValueError(f"Unsupported file type: {file_type}")
        
        # Convert to requested format
        if output_format == 'markdown':
            result['markdown_text'] = self._convert_to_markdown(result)
        elif output_format == 'plain_text':
            result['plain_text'] = self._convert_to_plain_text(result)
        elif output_format == 'json':
            pass  # Already in structured format
        
        return result
    
    def _detect_file_type(self, file_path: Path) -> str:
        """Detect whether file is PDF or image."""
        suffix = file_path.suffix.lower()
        
        if suffix == '.pdf':
            return 'pdf'
        elif suffix in ['.jpg', '.jpeg', '.png', '.tiff', '.tif', '.bmp', '.webp']:
            return 'image'
        else:
            # Try to detect by content
            try:
                with open(file_path, 'rb') as f:
                    header = f.read(8)
                    if header.startswith(b'%PDF'):
                        return 'pdf'
                    elif header.startswith(b'\xff\xd8\xff\xe0') or header.startswith(b'\x89PNG'):
                        return 'image'
            except:
                pass
        
        raise ValueError(f"Cannot detect file type for: {file_path}")
    
    def _process_pdf(self, pdf_path: Path) -> Dict[str, Any]:
        """Process PDF file."""
        logger.info(f"Processing PDF: {pdf_path}")
        
        # First try to extract text directly (digital PDF)
        text_content = self._extract_text_from_pdf(pdf_path)
        
        # If little text extracted, treat as scanned PDF
        if len(text_content.strip()) < 100:  # Arbitrary threshold
            logger.info("Little text extracted, treating as scanned PDF")
            return self._process_scanned_pdf(pdf_path)
        else:
            logger.info("Digital PDF detected, extracting text directly")
            return {
                'file_type': 'pdf',
                'content_type': 'digital',
                'pages': [{'page_num': 1, 'text': text_content}],
                'metadata': {
                    'total_pages': 1,
                    'extraction_method': 'direct_text'
                }
            }
    
    def _extract_text_from_pdf(self, pdf_path: Path) -> str:
        """Extract text from digital PDF."""
        try:
            from PyPDF2 import PdfReader
            
            reader = PdfReader(pdf_path)
            text_content = ""
            
            for page_num, page in enumerate(reader.pages, 1):
                page_text = page.extract_text()
                if page_text:
                    text_content += f"\n--- Page {page_num} ---\n{page_text}"
            
            return text_content
        except Exception as e:
            logger.error(f"Error extracting text from PDF: {e}")
            return ""
    
    def _process_scanned_pdf(self, pdf_path: Path) -> Dict[str, Any]:
        """Process scanned PDF using OCR."""
        logger.info("Processing scanned PDF with OCR")
        
        # Convert PDF to images
        try:
            from pdf2image import convert_from_path
            
            images = convert_from_path(pdf_path)
            pages = []
            
            for page_num, image in enumerate(images, 1):
                logger.info(f"Processing page {page_num}/{len(images)}")
                
                # Perform OCR on the image
                text = self._perform_ocr(image)
                pages.append({
                    'page_num': page_num,
                    'text': text
                })
            
            return {
                'file_type': 'pdf',
                'content_type': 'scanned',
                'pages': pages,
                'metadata': {
                    'total_pages': len(pages),
                    'extraction_method': 'ocr'
                }
            }
        except Exception as e:
            logger.error(f"Error processing scanned PDF: {e}")
            raise
    
    def _process_image(self, image_path: Path) -> Dict[str, Any]:
        """Process image file using OCR."""
        logger.info(f"Processing image: {image_path}")
        
        try:
            from PIL import Image
            
            image = Image.open(image_path)
            text = self._perform_ocr(image)
            
            return {
                'file_type': 'image',
                'content_type': 'ocr',
                'pages': [{'page_num': 1, 'text': text}],
                'metadata': {
                    'total_pages': 1,
                    'extraction_method': 'ocr',
                    'image_size': image.size
                }
            }
        except Exception as e:
            logger.error(f"Error processing image: {e}")
            raise
    
    def _perform_ocr(self, image) -> str:
        """Perform OCR on an image using available engine."""
        if self.ocr_engine == 'auto':
            # Try engines in order of preference: tesseract, easyocr, paddleocr
            for engine in ['tesseract', 'easyocr', 'paddleocr']:
                if engine in self.available_engines:
                    try:
                        logger.info(f"Trying OCR engine: {engine}")
                        if engine == 'tesseract':
                            return self._ocr_with_tesseract(image)
                        elif engine == 'easyocr':
                            return self._ocr_with_easyocr(image)
                        elif engine == 'paddleocr':
                            return self._ocr_with_paddleocr(image)
                    except Exception as e:
                        logger.warning(f"OCR engine {engine} failed: {e}")
                        continue
            raise RuntimeError("All OCR engines failed")
        else:
            engine = self.ocr_engine
            logger.info(f"Using OCR engine: {engine}")
            
            if engine == 'tesseract':
                return self._ocr_with_tesseract(image)
            elif engine == 'easyocr':
                return self._ocr_with_easyocr(image)
            elif engine == 'paddleocr':
                return self._ocr_with_paddleocr(image)
            else:
                raise ValueError(f"Unsupported OCR engine: {engine}")
    
    def _ocr_with_tesseract(self, image) -> str:
        """Perform OCR using Tesseract."""
        try:
            import pytesseract
            
            # Configure Tesseract
            config = f'--lang {self.language}'
            if self.preserve_layout:
                config += ' --psm 6'  # Assume uniform block of text
            
            text = pytesseract.image_to_string(image, config=config)
            return text
        except Exception as e:
            logger.error(f"Tesseract OCR error: {e}")
            raise
    
    def _ocr_with_easyocr(self, image) -> str:
        """Perform OCR using EasyOCR."""
        try:
            import easyocr
            import numpy as np
            
            # Convert PIL image to numpy array
            if hasattr(image, 'convert'):
                image_np = np.array(image.convert('RGB'))
            else:
                image_np = image
            
            # Initialize reader
            reader = easyocr.Reader([self.language])
            results = reader.readtext(image_np)
            
            # Extract text
            text_lines = []
            for (bbox, text, prob) in results:
                text_lines.append(text)
            
            return '\n'.join(text_lines)
        except Exception as e:
            logger.error(f"EasyOCR error: {e}")
            raise
    
    def _ocr_with_paddleocr(self, image) -> str:
        """Perform OCR using PaddleOCR."""
        try:
            from paddleocr import PaddleOCR
            import numpy as np
            
            # Convert PIL image to numpy array
            if hasattr(image, 'convert'):
                image_np = np.array(image.convert('RGB'))
            else:
                image_np = image
            
            # Initialize OCR
            ocr = PaddleOCR(use_angle_cls=True, lang=self.language)
            result = ocr.ocr(image_np, cls=True)
            
            # Extract text
            text_lines = []
            for line in result:
                if line:
                    for word_info in line:
                        if word_info:
                            text = word_info[1][0]
                            text_lines.append(text)
            
            return '\n'.join(text_lines)
        except Exception as e:
            logger.error(f"PaddleOCR error: {e}")
            raise
    
    def _convert_to_markdown(self, result: Dict) -> str:
        """Convert extracted content to Markdown format."""
        markdown_parts = []
        
        # Add title
        markdown_parts.append("# Extracted Document\n")
        
        # Process each page
        for page in result.get('pages', []):
            page_num = page.get('page_num', 1)
            text = page.get('text', '')
            
            if len(result.get('pages', [])) > 1:
                markdown_parts.append(f"\n## Page {page_num}\n")
            
            # Process text content
            processed_text = self._process_text_to_markdown(text)
            markdown_parts.append(processed_text)
        
        # Add metadata
        metadata = result.get('metadata', {})
        if metadata:
            markdown_parts.append("\n## Extraction Metadata\n")
            markdown_parts.append(f"- **Total Pages**: {metadata.get('total_pages', 'N/A')}")
            markdown_parts.append(f"- **Extraction Method**: {metadata.get('extraction_method', 'N/A')}")
            markdown_parts.append(f"- **File Type**: {result.get('file_type', 'N/A')}")
        
        return '\n'.join(markdown_parts)
    
    def _process_text_to_markdown(self, text: str) -> str:
        """Process raw text and convert to Markdown formatting."""
        if not text:
            return ""
        
        lines = text.split('\n')
        processed_lines = []
        
        for line in lines:
            line = line.strip()
            if not line:
                processed_lines.append('')
                continue
            
            # Simple heuristics for Markdown conversion
            # Detect headings (lines that are all caps or have specific patterns)
            if line.isupper() and len(line) < 100:
                processed_lines.append(f"### {line.title()}")
            # Detect list items
            elif line.startswith(('- ', '* ', '• ')):
                processed_lines.append(line)
            elif len(line) > 1 and line[0].isdigit() and line[1] in ['.', ')', ' ']:
                processed_lines.append(f"1. {line[2:].strip()}")
            # Detect code blocks (lines with specific patterns)
            elif any(keyword in line.lower() for keyword in ['function', 'class', 'def ', 'import ', 'from ']):
                processed_lines.append(f"```\n{line}\n```")
            else:
                processed_lines.append(line)
        
        return '\n'.join(processed_lines)
    
    def _convert_to_plain_text(self, result: Dict) -> str:
        """Convert extracted content to plain text."""
        text_parts = []
        
        for page in result.get('pages', []):
            text = page.get('text', '')
            if text:
                text_parts.append(text)
        
        return '\n\n'.join(text_parts)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description='Convert documents to Markdown format')
    parser.add_argument('input_file', help='Input image or PDF file')
    parser.add_argument('-o', '--output', help='Output file path')
    parser.add_argument('-f', '--format', choices=['markdown', 'plain_text', 'json'], 
                       default='markdown', help='Output format')
    parser.add_argument('-l', '--language', default='en', help='Document language')
    parser.add_argument('--ocr-engine', choices=['auto', 'tesseract', 'easyocr', 'paddleocr'],
                       default='auto', help='OCR engine to use')
    parser.add_argument('--preserve-layout', action='store_true', default=True,
                       help='Preserve document layout')
    parser.add_argument('--extract-tables', action='store_true', default=True,
                       help='Extract tables separately')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Configuration
    config = {
        'ocr_engine': args.ocr_engine,
        'language': args.language,
        'preserve_layout': args.preserve_layout,
        'extract_tables': args.extract_tables
    }
    
    try:
        # Process document
        processor = DocumentProcessor(config)
        result = processor.process_file(args.input_file, args.format)
        
        # Output result
        if args.format == 'json':
            output = json.dumps(result, indent=2, ensure_ascii=False)
        elif args.format == 'markdown':
            output = result.get('markdown_text', '')
        elif args.format == 'plain_text':
            output = result.get('plain_text', '')
        
        # Write to file or stdout
        if args.output:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(output)
            print(f"Output written to: {args.output}")
        else:
            print(output)
        
        # Print summary
        if args.verbose:
            print("\n=== Processing Summary ===")
            print(f"File: {args.input_file}")
            print(f"Type: {result.get('file_type', 'unknown')}")
            print(f"Pages: {result.get('metadata', {}).get('total_pages', 'N/A')}")
            print(f"Method: {result.get('metadata', {}).get('extraction_method', 'N/A')}")
        
    except Exception as e:
        logger.error(f"Error processing document: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()