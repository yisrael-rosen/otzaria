import 'package:flutter/material.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/models/app_model.dart';
import 'package:otzaria/models/tabs.dart';
import 'package:provider/provider.dart';

class FullTextSettingsScreen extends StatelessWidget {
  const FullTextSettingsScreen({
    Key? key,
    required this.tab,
  }) : super(key: key);
  final SearchingTab tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: Text('חיפוש מקורב')),
                ValueListenableBuilder(
                    valueListenable: tab.aproximateSearch,
                    builder: (context, aproximateSearch, child) {
                      return Switch(
                          value: aproximateSearch,
                          onChanged: (value) =>
                              tab.aproximateSearch.value = value);
                    }),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: const Text(
                          'עדכון האינדקס עלול לקחת זמן ומשאבים רבים. להמשיך?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('ביטול'),
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                        ),
                        TextButton(
                          child: const Text('אישור'),
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                        ),
                      ],
                    ),
                  );
                  if (result == true) {
                    context.read<AppModel>().addAllTextsToTantivy();
                  }
                },
                child: const Text('עדכון אינדקס'),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: TantivyDataProvider.instance.isIndexing,
              builder: (context, isIndexing, child) {
                return Column(
                  children: [
                    if (isIndexing)
                      ValueListenableBuilder(
                        valueListenable:
                            TantivyDataProvider.instance.numOfbooksDone,
                        builder: (context, numOfbooksDone, child) => Column(
                          children: [
                            ValueListenableBuilder(
                              valueListenable:
                                  TantivyDataProvider.instance.numOfbooksTotal,
                              builder: (context, valueTotal, child) {
                                if (valueTotal == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  child: Column(
                                    children: [
                                      LinearProgressIndicator(
                                        borderRadius: BorderRadius.circular(20),
                                        value: numOfbooksDone! / valueTotal,
                                      ),
                                      Text('$numOfbooksDone / $valueTotal'),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                onPressed: () => TantivyDataProvider
                                    .instance.isIndexing.value = false,
                                child: Text('עצור'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'מידע על ספרים מאונדקסים',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: TantivyDataProvider.instance.updateTimer,
                      builder: (context, updateTimer, child) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            'זמן עדכון: ${updateTimer.toStringAsFixed(2)} שניות',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder(
                      valueListenable:
                          TantivyDataProvider.instance.totalUpdatedInfo,
                      builder: (context, totalUpdatedInfo, child) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            'סך המידע שעודכן: ${(totalUpdatedInfo / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable:
                            TantivyDataProvider.instance.indexedBooks,
                        builder: (context, indexedBooks, child) {
                          return ListView.builder(
                            itemCount: indexedBooks.length,
                            itemBuilder: (context, index) {
                              final book = indexedBooks[index];
                              return Card(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(book.title),
                                  subtitle: Text(
                                    'זמן אינדוקס: ${book.indexingTime.toStringAsFixed(2)} שניות\n'
                                    'גודל: ${(book.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
