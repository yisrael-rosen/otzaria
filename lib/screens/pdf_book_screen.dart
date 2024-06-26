import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'pdf_search_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_outlines_screen.dart';
import '../widgets/password_dialog.dart';
import 'pdf_thumbnails_screen.dart';
import 'package:otzaria/model/books.dart';

class PdfBookViewr extends StatefulWidget {
  final PdfBookTab tab;
  final PdfViewerController controller;
  final void Function(
      {required String ref,
      required String path,
      required int index}) addBookmarkCallback;
  const PdfBookViewr(
      {super.key,
      required this.tab,
      required this.controller,
      required this.addBookmarkCallback});

  @override
  State<PdfBookViewr> createState() => _PdfBookViewrState();
}

class _PdfBookViewrState extends State<PdfBookViewr>
    with AutomaticKeepAliveClientMixin<PdfBookViewr> {
  final documentRef = ValueNotifier<PdfDocumentRef?>(null);
  final showLeftPane = ValueNotifier<bool>(false);
  final outline = ValueNotifier<List<PdfOutlineNode>?>(null);
  late final textSearcher = PdfTextSearcher(widget.controller)
    ..addListener(_update);

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    textSearcher.removeListener(_update);
    textSearcher.dispose();
    showLeftPane.dispose();
    outline.dispose();
    documentRef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'חיפוש וניווט',
          onPressed: () {
            showLeftPane.value = !showLeftPane.value;
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'הוספת סימניה',
            onPressed: () => widget.addBookmarkCallback(
                ref:
                    '${widget.tab.title} עמוד ${widget.controller.pageNumber ?? 1}',
                path: widget.tab.path,
                index: widget.controller.pageNumber ?? 1),
          ),
          IconButton(
            icon: const Icon(
              Icons.zoom_in,
            ),
            tooltip: 'הגדל',
            onPressed: () => widget.controller.zoomUp(),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'הקטן',
            onPressed: () => widget.controller.zoomDown(),
          ),
          IconButton(
            icon: const Icon(Icons.first_page),
            tooltip: 'תחילת הספר',
            onPressed: () => widget.controller.goToPage(pageNumber: 1),
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            tooltip: 'סוף הספר',
            onPressed: () => widget.controller
                .goToPage(pageNumber: widget.controller.pages.length),
          ),
        ],
      ),
      body: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: ValueListenableBuilder(
              valueListenable: showLeftPane,
              builder: (context, showLeftPane, child) => SizedBox(
                width: showLeftPane ? 300 : 0,
                child: child!,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 4, 0),
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(tabs: [
                        Tab(text: 'חיפוש'),
                        Tab(text: 'ניווט'),
                        Tab(text: 'דפים'),
                      ]),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // NOTE: documentRef is not explicitly used but it indicates that
                            // the document is changed.
                            ValueListenableBuilder(
                              valueListenable: documentRef,
                              builder: (context, documentRef, child) => child!,
                              child:
                                  PdfBookSearchView(textSearcher: textSearcher),
                            ),
                            ValueListenableBuilder(
                              valueListenable: outline,
                              builder: (context, outline, child) => OutlineView(
                                outline: outline,
                                controller: widget.controller,
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: documentRef,
                              builder: (context, documentRef, child) => child!,
                              child:
                                  ThumbnailsView(controller: widget.controller),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                PdfViewer.file(
                  widget.tab.path,
                  initialPageNumber: widget.tab.pageNumber,
                  // PdfViewer.file(
                  //   r"D:\pdfrx\example\assets\hello.pdf",
                  // PdfViewer.uri(
                  //   Uri.parse(
                  //       'https://espresso3389.github.io/pdfrx/assets/assets/PDF32000_2008.pdf'),
                  // PdfViewer.uri(
                  //   Uri.parse(kIsWeb
                  //       ? 'assets/assets/hello.pdf'
                  //       : 'https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf'),
                  // Set password provider to show password dialog
                  passwordProvider: () => passwordDialog(context),
                  controller: widget.controller,
                  params: PdfViewerParams(
                    enableTextSelection: true,
                    maxScale: 8,
                    // code to display pages horizontally
                    // layoutPages: (pages, params) {
                    //   final height = pages.fold(
                    //           templatePage.height,
                    //           (prev, page) => max(prev, page.height)) +
                    //       params.margin * 2;
                    //   final pageLayouts = <Rect>[];
                    //   double x = params.margin;
                    //   for (var page in pages) {
                    //     page ??= templatePage; // in case the page is not loaded yet
                    //     pageLayouts.add(
                    //       Rect.fromLTWH(
                    //         x,
                    //         (height - page.height) / 2, // center vertically
                    //         page.width,
                    //         page.height,
                    //       ),
                    //     );
                    //     x += page.width + params.margin;
                    //   }
                    //   return PdfPageLayout(
                    //     pageLayouts: pageLayouts,
                    //     documentSize: Size(x, height),
                    //   );
                    // },
                    //
                    // Scroll-thumbs example
                    //
                    viewerOverlayBuilder: (context, size) => [
                      // Show vertical scroll thumb on the right; it has page number on it
                      PdfViewerScrollThumb(
                        controller: widget.controller,
                        orientation: ScrollbarOrientation.right,
                        thumbSize: const Size(40, 25),
                        thumbBuilder:
                            (context, thumbSize, pageNumber, controller) =>
                                Container(
                          color: Colors.black,
                          child: Center(
                            child: Text(
                              pageNumber.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      // Just a simple horizontal scroll thumb on the bottom
                      PdfViewerScrollThumb(
                        controller: widget.controller,
                        orientation: ScrollbarOrientation.bottom,
                        thumbSize: const Size(80, 5),
                        thumbBuilder:
                            (context, thumbSize, pageNumber, controller) =>
                                Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                    //
                    // Loading progress indicator example
                    //
                    loadingBannerBuilder:
                        (context, bytesDownloaded, totalBytes) => Center(
                      child: CircularProgressIndicator(
                        value: totalBytes != null
                            ? bytesDownloaded / totalBytes
                            : null,
                        backgroundColor: Colors.grey,
                      ),
                    ),
                    //
                    // Link handling example
                    //

                    linkWidgetBuilder: (context, link, size) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (link.url != null) {
                            navigateToUrl(link.url!);
                          } else if (link.dest != null) {
                            widget.controller.goToDest(link.dest);
                          }
                        },
                        hoverColor: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    pagePaintCallbacks: [
                      textSearcher.pageTextMatchPaintCallback
                    ],
                    onDocumentChanged: (document) async {
                      if (document == null) {
                        documentRef.value = null;
                        outline.value = null;
                      }
                    },
                    onViewerReady: (document, controller) async {
                      documentRef.value = controller.documentRef;
                      outline.value = await document.loadOutline();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> navigateToUrl(Uri url) async {
    if (await shouldOpenUrl(context, url)) {
      await launchUrl(url);
    }
  }

  Future<bool> shouldOpenUrl(BuildContext context, Uri url) async {
    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('לעבור לURL?'),
          content: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'האם לעבור לכתובת הבאה\n'),
                  TextSpan(
                    text: url.toString(),
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('עבור'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  bool get wantKeepAlive => true;
}
