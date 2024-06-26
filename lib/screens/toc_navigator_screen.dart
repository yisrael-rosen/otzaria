import 'dart:io';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:otzaria/model/books.dart';

class TocViewer extends StatefulWidget {
  final Future<List<TocEntry>> toc;
  final ItemScrollController scrollController;
  final void Function() closeLeftPaneCallback;

  TocViewer({
    super.key,
    required this.toc,
    required this.scrollController,
    required this.closeLeftPaneCallback,
  });

  @override
  State<TocViewer> createState() => _TocViewerState();
}

class _TocViewerState extends State<TocViewer>
    with AutomaticKeepAliveClientMixin<TocViewer> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
        future: widget.toc,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView(
              children: _buildTree(snapshot.data!),
            );
          }
          return const Center(child: CircularProgressIndicator());
        });
  }

  List<Widget> _buildTree(List<TocEntry> entries) {
    List<Widget> widgets = [];
    for (final TocEntry entry in entries) {
      if (entry.children.isEmpty) {
        // Leaf node (no children)
        widgets.add(
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 10 * entry.level.toDouble(), 0),
            child: ListTile(
              title: Text(entry.text),
              onTap: () {
                widget.scrollController.scrollTo(
                  index: entry.index,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                );
                if (Platform.isAndroid) {
                  widget.closeLeftPaneCallback();
                }
              },
            ),
          ),
        );
      } else {
        // Parent node with children
        widgets.add(
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 10 * entry.level.toDouble(), 0),
            child: ExpansionTile(
              title: Text(entry.text),
              children:
                  _buildTree(entry.children), // Recursively build children
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  bool get wantKeepAlive => true;
}
