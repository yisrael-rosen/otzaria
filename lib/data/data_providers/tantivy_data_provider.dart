import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/library.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:otzaria/src/rust/api/search_engine.dart';
import 'package:otzaria/src/rust/frb_generated.dart';

class IndexedBookInfo {
  final String title;
  final double indexingTime;
  final int size;

  IndexedBookInfo({required this.title, required this.indexingTime, required this.size});

  Map<String, dynamic> toJson() => {
    'title': title,
    'indexingTime': indexingTime,
    'size': size,
  };

  factory IndexedBookInfo.fromJson(Map<String, dynamic> json) {
    return IndexedBookInfo(
      title: json['title'],
      indexingTime: json['indexingTime'],
      size: json['size'],
    );
  }
}

class TantivyDataProvider {
  static final TantivyDataProvider _singleton = TantivyDataProvider();
  static TantivyDataProvider instance = _singleton;

  ValueNotifier<int?> numOfbooksDone = ValueNotifier(null);
  ValueNotifier<int?> numOfbooksTotal = ValueNotifier(null);
  ValueNotifier<bool> isIndexing = ValueNotifier(false);
  ValueNotifier<List<IndexedBookInfo>> indexedBooks = ValueNotifier([]);
  ValueNotifier<double> updateTimer = ValueNotifier(0.0);
  ValueNotifier<double> totalUpdatedInfo = ValueNotifier(0.0);
  late List booksDone;
  late BookIndex _bookIndex;

  TantivyDataProvider() {
    booksDone = Settings.getValue<List>('key-books-done') ?? [];
    final List<dynamic> savedIndexedBooks = Settings.getValue<List>('key-indexed-books') ?? [];
    indexedBooks.value = savedIndexedBooks.map((book) => IndexedBookInfo.fromJson(book)).toList();
    _initializeBookIndex();
  }

  void _initializeBookIndex() {
    final index = BookIndex.create();
    if (index != null) {
      _bookIndex = index;
    } else {
      print('Failed to create book index');
    }
  }

  saveBooksDoneToDisk() {
    Settings.setValue('key-books-done', booksDone);
  }

  saveIndexedBooksToDisk() {
    Settings.setValue('key-indexed-books', indexedBooks.value.map((book) => book.toJson()).toList());
  }

  void startNewIndexingSession() {
    updateTimer.value = 0.0;
    totalUpdatedInfo.value = 0.0;
    indexedBooks.value = [];
    isIndexing.value = true;
    numOfbooksDone.value = 0;
  }

  void addBookToIndex(IndexedBookInfo book) {
    final List<IndexedBookInfo> currentBooks = List.from(indexedBooks.value);
    currentBooks.insert(0, book); // Add the new book to the beginning of the list
    indexedBooks.value = currentBooks;
    
    totalUpdatedInfo.value += book.size;
    updateTimer.value += book.indexingTime;
    saveIndexedBooksToDisk();
  }

  Future<List<SearchResult>> searchTexts(String query, List<String> books) async {
    return _bookIndex.search(query: query);
  }

  Stream<List<SearchResult>> searchTextsStream(String query, List<String> books) async* {
    yield _bookIndex.search(query: query);
  }

  addAllTBooksToTantivy(Library library, {int start = 0, int end = 100000}) async {
    startNewIndexingSession();
    var allBooks = library.getAllBooks();
    allBooks = allBooks.getRange(start, min(end, allBooks.length)).toList();

    numOfbooksTotal.value = allBooks.length;

    for (Book book in allBooks) {
      if (!isIndexing.value) {
        return;
      }
      print('Adding ${book.title} to Tantivy');
      try {
        final stopwatch = Stopwatch()..start();
        int size = 0;
        if (book is TextBook) {
          size = await addTextsToTantivy(book);
        } else if (book is PdfBook) {
          size = await addPdfTextsToTantivy(book);
        }
        stopwatch.stop();
        final indexingTime = stopwatch.elapsedMilliseconds / 1000.0;
        print('Adding ${book.title} to Tantivy took ${indexingTime} seconds');
        
        addBookToIndex(IndexedBookInfo(
          title: book.title,
          indexingTime: indexingTime,
          size: size,
        ));
      } catch (e) {
        print('Error adding ${book.title} to Tantivy: $e');
      }
    }

    numOfbooksDone.value = null;
    numOfbooksTotal.value = null;
    isIndexing.value = false;
  }

  Future<int> addTextsToTantivy(TextBook book) async {
    final stopwatch = Stopwatch()..start();
    final text = await book.text;
    final title = book.title;
    final author = book.author;
    //final topics = book.topics is Iterable ? book.topics.join(', ') : book.topics.toString();

    final hash = sha1.convert(utf8.encode(text)).toString();
    if (booksDone.contains(hash)) {
      print('${book.title} already in Tantivy');
      //numOfbooksDone.value = numOfbooksDone.value! + 1;
    //  stopwatch.stop();
      print('Checking ${book.title} took ${stopwatch.elapsed}');
     // return 0;
    }

    final texts = text.split('\n');
    for (int i = 0; i < texts.length; i++) {
      if (!isIndexing.value) {
        return 0;
      }
      final success = _bookIndex.addBook(
        title: title,
        text: texts[i],
        id: BigInt.parse(hash + i.toString(), radix: 16),
        line: BigInt.from(i),
      );
      if (!success) {
        print('Failed to add line $i of ${book.title} to Tantivy');
      }
    }
    _bookIndex.commit();
    booksDone.add(hash);
    saveBooksDoneToDisk();
    print('Added ${book.title} to Tantivy');
    final size = utf8.encode(text).length;
    print('Size of added content: $size bytes');
    numOfbooksDone.value = numOfbooksDone.value! + 1;
    stopwatch.stop();
    print('Adding ${book.title} to Tantivy took ${stopwatch.elapsed}');
    return size;
  }

  Future<int> addPdfTextsToTantivy(PdfBook book) async {
    final stopwatch = Stopwatch()..start();
    final data = await File(book.path).readAsBytes();
    final hash = sha1.convert(data).toString();
    if (booksDone.contains(hash)) {
      print('${book.title} already in Tantivy');
   //   numOfbooksDone.value = numOfbooksDone.value! + 1;
   //   return 0;
    }
    final pages = await PdfDocument.openData(data).then((value) => value.pages);
    final title = book.title;
    final author = book.author;
    //final topics = book.topics is Iterable ? book.topics.join(', ') : book.topics.toString();

    int totalSize = 0;
    for (int i = 0; i < pages.length; i++) {
      final texts = (await pages[i].loadText()).fullText.split('\n');
      for (int j = 0; j < texts.length; j++) {
        if (!isIndexing.value) {
          return 0;
        }
        final text = texts[j];
        totalSize += utf8.encode(text).length;
        final success = _bookIndex.addBook(
          title: title,
          text: text,
          id: BigInt.parse(hash + i.toString() + j.toString(), radix: 16),
          line: BigInt.from(i),
        );
        if (!success) {
          print('Failed to add line $j of page $i of ${book.title} to Tantivy');
        }
      }
    }
    _bookIndex.commit();
    booksDone.add(hash);
    saveBooksDoneToDisk();
    print('Added ${book.title} to Tantivy');
    print('Size of added content: $totalSize bytes');
    numOfbooksDone.value = numOfbooksDone.value! + 1;
    stopwatch.stop();
    print('Adding ${book.title} to Tantivy took ${stopwatch.elapsed}');
    return totalSize;
  }
}