import 'dart:async';

class StreamedList<T> {
  StreamController<List<T>> _controller = StreamController.broadcast();

  Stream<List<T>> get data => _controller.stream;

  List<T> _list = [];

  void updateList(List<T> list) {
    _list = list;
    dispatch();
  }

  void addToList(T value) {
    _list.add(value);
    dispatch();
  }

  void dispatch() {
    _controller.sink.add(_list);
  }

  void dispose() {
    _list = [];
    _controller.close();
  }
}
