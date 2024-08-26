import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/models/app_model.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/tabs.dart';
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:otzaria/screens/full_text_search/full_text_left_pane.dart';
import 'package:provider/provider.dart';
import 'package:otzaria/src/rust/api/search_engine.dart';
import 'dart:async';

class TantivyFullTextSearch extends StatefulWidget {
  final SearchingTab tab;
  const TantivyFullTextSearch({Key? key, required this.tab}) : super(key: key);
  @override
  State<TantivyFullTextSearch> createState() => _TantivyFullTextSearchState();
}

class _TantivyFullTextSearchState extends State<TantivyFullTextSearch> {
  StreamController<List<SearchResult>> _resultsController = StreamController<List<SearchResult>>.broadcast();
  late TextEditingController queryController;
  ValueNotifier isLeftPaneOpen = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    queryController = widget.tab.queryController;
    widget.tab.aproximateSearch.addListener(() => updateResults());
    widget.tab.booksToSearch.addListener(() => updateResults());
    print('PerformanceLog: TantivyFullTextSearch initialized');
  }

  @override
  void dispose() {
    _resultsController.close();
    super.dispose();
  }

  void updateResults() {
    if (queryController.text.isEmpty) {
      _resultsController.add([]);
      print('PerformanceLog: Empty query, no search performed');
    } else {
      final stopwatch = Stopwatch()..start();
      
      final booksToSearch =
          widget.tab.booksToSearch.value.map<String>((e) => e.title).toList();
      
      Stream<List<SearchResult>> searchStream;
      if (!widget.tab.aproximateSearch.value) {
        searchStream = TantivyDataProvider.instance
            .searchTextsStream('"${queryController.text}"', booksToSearch);
      } else {
        searchStream = TantivyDataProvider.instance
            .searchTextsStream(queryController.text, booksToSearch);
      }
      
      print('PerformanceLog: Search initiated. Query: ${queryController.text}, Books: ${booksToSearch.length}');
      
      searchStream.listen(
        (data) {
          stopwatch.stop();
          print('PerformanceLog: Search completed in ${stopwatch.elapsedMilliseconds}ms. Results: ${data.length}');
          _resultsController.add(data);
        },
        onError: (error) {
          print('PerformanceLog: Search error: $error');
          _resultsController.addError(error);
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('PerformanceLog: Building TantivyFullTextSearch widget');
    final buildStopwatch = Stopwatch()..start();
    
    final scaffold = Scaffold(
      body: ValueListenableBuilder(
          valueListenable: isLeftPaneOpen,
          builder: (context, value, child) {
            return Row(
              children: [
                if (!isLeftPaneOpen.value)
                  const SizedBox.shrink()
                else
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                        child: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            isLeftPaneOpen.value = !isLeftPaneOpen.value;
                          },
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: SizedBox(
                      width: isLeftPaneOpen.value ? 350 : 0,
                      child: FullTextLeftPane(tab: widget.tab),
                    )),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (!isLeftPaneOpen.value)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                              child: IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () {
                                  isLeftPaneOpen.value = !isLeftPaneOpen.value;
                                },
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(60, 5, 60, 10),
                              child: TextField(
                                autofocus: true,
                                controller: queryController,
                                onChanged: (e) => updateResults(),
                                decoration: InputDecoration(
                                  hintText: "חפש כאן..",
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      queryController.clear();
                                      updateResults();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: StreamBuilder<List<SearchResult>>(
                            stream: _resultsController.stream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text('Error: ${snapshot.error}'));
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(child: Text('No results'));
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final result = snapshot.data![index];
                                  return ListTile(
                                    onTap: () {
                                      final openTabStopwatch = Stopwatch()..start();
                                      context.read<AppModel>().openTab(
                                            TextBookTab(
                                                book: TextBook(
                                                  title: result.title,
                                                ),
                                                index: result.line.toInt(),
                                                searchText:
                                                    queryController.text),
                                          );
                                      print('PerformanceLog: Tab opened in ${openTabStopwatch.elapsedMilliseconds}ms');
                                    },
                                    title: FutureBuilder(
                                        future: refFromIndex(
                                            result.line.toInt(),
                                            TextBook(
                                                    title: result.title)
                                                .tableOfContents),
                                        builder: (context, ref) {
                                          if (!ref.hasData) {
                                            return Text('${result.title} ...');
                                          }
                                          return Text(ref.data!);
                                        }),
                                    subtitle: Html(
                                        data: highLight(
                                            result.text,
                                            queryController.text)),
                                  );
                                },
                              );
                            }),
                      )
                    ],
                  ),
                ),
              ],
            );
          }),
    );
    
    buildStopwatch.stop();
    print('PerformanceLog: TantivyFullTextSearch widget built in ${buildStopwatch.elapsedMilliseconds}ms');
    
    return scaffold;
  }
}