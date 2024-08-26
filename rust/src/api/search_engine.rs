use tantivy::schema::{Schema, STORED, TEXT, OwnedValue};
use tantivy::{doc, Index, TantivyDocument};
use tantivy::query::QueryParser;
use tantivy::collector::TopDocs;
use tantivy::directory::MmapDirectory;
use std::path::Path;
#[flutter_rust_bridge::frb(opaque)]
pub struct BookIndex {
    index: Index,
    writer: tantivy::IndexWriter,
}

#[flutter_rust_bridge::frb(opaque)]
pub struct SearchResult {
    pub title: String,
    pub text: String,
    pub id: u64,
    pub line: u64,
}

impl BookIndex {
    #[flutter_rust_bridge::frb(sync)]
    pub fn create() -> Option<Self> {
        let path = std::path::Path::new(r"C:\Users\ROSEN\dev\otzaria\book_index"); // Define the path variable

    let mut schema_builder = Schema::builder();
        let title = schema_builder.add_text_field("title", TEXT | STORED);
        let text = schema_builder.add_text_field("text", TEXT);
        let id = schema_builder.add_u64_field("id", STORED);
        let line = schema_builder.add_u64_field("line", STORED);
        let schema = schema_builder.build();

        let directory = match MmapDirectory::open(path) {
            Ok(dir) => dir,
            Err(_) => return None,
        };

        let index = match Index::open_or_create(directory, schema) {
            Ok(idx) => idx,
            Err(_) => return None,
        };

        let writer = match index.writer(50_000_000) {
            Ok(writer) => writer,
            Err(_) => return None,
        };

        Some(BookIndex { index, writer })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn add_book(&mut self, title: String, text: String, id: u64, line: u64) -> bool {
        let schema = self.index.schema();
        let title_field = schema.get_field("title").unwrap();
        let text_field = schema.get_field("text").unwrap();
        let id_field = schema.get_field("id").unwrap();
        let line_field = schema.get_field("line").unwrap();

        let result = self.writer.add_document(doc!(
            title_field => title,
            text_field => text,
            id_field => id,
            line_field => line,
        ));

        result.is_ok()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn commit(&mut self) -> bool {
        self.writer.commit().is_ok()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn search(&self, query: String) -> Vec<SearchResult> {
        let reader = match self.index.reader() {
            Ok(reader) => reader,
            Err(_) => return Vec::new(),
        };
        let searcher = reader.searcher();
        let schema = self.index.schema();
        let title = schema.get_field("title").unwrap();
        let text = schema.get_field("text").unwrap();
        let id = schema.get_field("id").unwrap();
        let line = schema.get_field("line").unwrap();

        let query_parser = QueryParser::for_index(&self.index, vec![text]);
        let query = match query_parser.parse_query(&query) {
            Ok(query) => query,
            Err(_) => return Vec::new(),
        };
        let top_docs = match searcher.search(&query, &TopDocs::with_limit(100)) {
            Ok(top_docs) => top_docs,
            Err(_) => return Vec::new(),
        };

        let mut results = Vec::new();
        for (_score, doc_address) in top_docs {
            match searcher.doc::<TantivyDocument>(doc_address) {
                Ok(retrieved_doc) => {
                    let title = retrieved_doc
                        .get_first(title)
                        .and_then(|v| match v {
                            OwnedValue::Str(s) => Some(s.clone()),
                            _ => None,
                        })
                        .unwrap_or_default();
                    let text = retrieved_doc
                        .get_first(text)
                        .and_then(|v| match v {
                            OwnedValue::Str(s) => Some(s.clone()),
                            _ => None,
                        })
                        .unwrap_or_default();
                    let id = retrieved_doc
                        .get_first(id)
                        .and_then(|v| match v {
                            OwnedValue::U64(y) => Some(*y),
                            _ => None,
                        })
                        .unwrap_or_default();
                    let line = retrieved_doc
                        .get_first(line)
                        .and_then(|v| match v {
                            OwnedValue::U64(y) => Some(*y),
                            _ => None,
                        })
                        .unwrap_or_default();
                    results.push(SearchResult { title, text, id, line });
                },
                Err(_) => continue,
            }
        }
        results
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_book_index() {
        // יצירת אינדקס חדש
        
        // Create a new index
        let mut book_index = BookIndex::create().expect("Failed to create BookIndex");
        // ... rest of the test ...
    
        // הוספת מספר ספרים
        assert!(book_index.add_book("1984".to_string(), "George Orwell".to_string(), 1, 10));
        assert!(book_index.add_book("To Kill a Mockingbird".to_string(), "Harper Lee".to_string(), 2, 20));
        assert!(book_index.add_book("The Great Gatsby".to_string(), "F. Scott Fitzgerald".to_string(), 3, 30));
        assert!(book_index.add_book("The ".to_string(), "F. Scott Fitzgerald".to_string(), 3, 30));

        // ביצוע commit
        assert!(book_index.commit());

        // חיפוש ספר קיים
        let results = book_index.search("George".to_string());
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "1984");
       // assert_eq!(results[0].text, "George Orwell");
        assert_eq!(results[0].id, 1);
        assert_eq!(results[0].line, 10);

        // חיפוש חלקי
        let results = book_index.search("Harper".to_string());
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "To Kill a Mockingbird");

        // חיפוש שמחזיר מספר תוצאות
        let results = book_index.search("Scott".to_string());
        assert_eq!(results.len(), 2);  // "The Great Gatsby" ו- "To Kill a Mockingbird" (חלק מהכותרת)

        // חיפוש שלא מחזיר תוצאות
        let results = book_index.search("Nonexistent Book".to_string());
        assert_eq!(results.len(), 0);
    }
}