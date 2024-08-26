import 'dart:math';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/library.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';

addTextsToTantivy(Library library, {int start = 0, int end = 100000}) async {
  await TantivyDataProvider.instance
      .addAllTBooksToTantivy(library, start: start, end: end);
}

addTextToTantivy(TextBook book) async {
  await TantivyDataProvider.instance.addTextsToTantivy(book);
}
