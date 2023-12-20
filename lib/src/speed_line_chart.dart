import 'package:flutter/material.dart';
import 'package:flutter_speed_chart/src/date_value_pair.dart';
import 'package:flutter_speed_chart/src/legend.dart';
import 'package:flutter_speed_chart/src/line_chart_painter.dart';
import 'package:flutter_speed_chart/src/line_series.dart';
import 'package:intl/intl.dart';

class LineSeriesX {
  const LineSeriesX({
    required this.name,
    required this.color,
    required this.dataList,
    required this.dataMap,
    required this.startIndexes,
    this.maxYAxisValue,
    this.minYAxisValue,
  });

  final String name;
  final Color color;
  final List<DateValuePair> dataList;
  final Map<DateTime, double?> dataMap;
  final List<int> startIndexes;
  final double? maxYAxisValue;
  final double? minYAxisValue;
}

class SpeedLineChart extends StatefulWidget {
  final List<LineSeries> lineSeriesCollection;
  final String title;
  final bool showLegend;
  final bool showMultipleYAxises;

  const SpeedLineChart({
    Key? key,
    required this.lineSeriesCollection,
    this.title = '',
    this.showLegend = true,
    this.showMultipleYAxises = false,
  }) : super(key: key);

  @override
  _SpeedLineChartState createState() => _SpeedLineChartState();
}

class _SpeedLineChartState extends State<SpeedLineChart> {
  bool _showTooltip = false;

  double _longPressX = 0.0;
  final double _leftOffset = 50; // 완쪽 여백
  final double _rightOffset = 60; // 오른쪽 여백

  double _offset = 0.0;
  double _scale = 1.0;
  double _lastScaleValue = 1.0;

  double _minValue = 0.0;
  double _maxValue = 0.0;
  DateTime? _minDate;
  DateTime? _maxDate;
  double _xRange = 0.0;
  double _yRange = 0.0;

  // multiple Y-axis
  final List<double> _yRanges = [];
  final List<double> _minValues = [];
  final List<double> _maxValues = [];

  double _focalPointX = 0.0;
  double _lastUpdateFocalPointX = 0.0;
  double _deltaFocalPointX = 0.0;
  late final LineSeriesX _longestLineSeriesX;
  late final List<LineSeriesX> _lineSeriesXCollection; // 전체 데이터

  List<LineSeriesX> _getLineSeriesXCollection() { // 데이처 초기 셋팅
    List<LineSeriesX> lineSeriesXCollection = [];
    for (LineSeries lineSeries in widget.lineSeriesCollection) {
      Map<DateTime, double?> dataMap = {};
      List<int> startIndexes = [];

      for (int i = 0; i < lineSeries.dataList.length; i++) {
        DateTime dateTime = lineSeries.dataList[i].dateTime;
        double? value = lineSeries.dataList[i].value;
        dataMap[dateTime] = value;

        if (i > 0) {
          if (value != null && lineSeries.dataList[i - 1].value == null) {
            startIndexes.add(i);
          }
        }
      }

      lineSeriesXCollection.add(LineSeriesX(
        name: lineSeries.name,
        color: lineSeries.color,
        dataList: lineSeries.dataList, // reference
        dataMap: dataMap,
        startIndexes: startIndexes,
        minYAxisValue: lineSeries.minYAxisValue,
        maxYAxisValue: lineSeries.maxYAxisValue,
      ));
    }
    return lineSeriesXCollection;
  }

  double getMaximumYAxisValue(
      {required double tempMaxValue, required double tempMinValue}) {
    double maximumYAxisValue = 0.0;

    //음수값인 경우
    // -2는 소수점과 그 뒤의 숫자를 제거하는 것임.
    int factor = tempMaxValue.toString().replaceFirst('-', '').length - 2;

    if ((tempMaxValue - tempMinValue).abs() >= 1000) {
      maximumYAxisValue = tempMaxValue + 100 * (factor + 10);
    } else if ((tempMaxValue - tempMinValue).abs() >= 100) {
      maximumYAxisValue = tempMaxValue + 100 * (factor + 2);
    } else if ((tempMaxValue - tempMinValue).abs() >= 10) {
      maximumYAxisValue = tempMaxValue + 10 * factor;
    } else {
      maximumYAxisValue = tempMaxValue + (factor + 1);
    }

    return maximumYAxisValue;
  }

  double getMinimumYAxisValue(
      {required double tempMaxValue, required double tempMinValue}) {
    double minimumYAxisValue = 0.0;

    //음수값인 경우
    // -2는 소수점과 그 뒤의 숫자를 제거하는 것.
    int factor = tempMinValue.toString().replaceFirst('-', '').length - 2;

    if ((tempMaxValue - tempMinValue).abs() >= 1000) { // 이 공식은 스텍오버플로우에서 구함.
      minimumYAxisValue = tempMinValue - 100 * (factor + 10);
    } else if ((tempMaxValue - tempMinValue).abs() >= 100) {
      minimumYAxisValue = tempMinValue - 100 * (factor + 2);
    } else if ((tempMaxValue - tempMinValue).abs() >= 10) {
      minimumYAxisValue = tempMinValue - 10 * factor;
    } else {
      minimumYAxisValue = tempMinValue - (factor + 1);
    }

    return minimumYAxisValue; // 최솟값을 리턴한다
  }

  void setMinValueAndMaxValue() {
    List<double?> allValues = _lineSeriesXCollection
        .expand((lineSeries) => lineSeries.dataMap.values)
        .toList();

    List<double> allMaxYAxisValues = [];
    List<double> allMinYAxisValues = [];

    for (LineSeriesX lineSeriesX in _lineSeriesXCollection) {
      if (lineSeriesX.maxYAxisValue != null) {
        allMaxYAxisValues.add(lineSeriesX.maxYAxisValue!);
      }
      if (lineSeriesX.minYAxisValue != null) {
        allMinYAxisValues.add(lineSeriesX.minYAxisValue!);
      }
    }

    allValues.removeWhere((element) => element == null);

    List<double?> allNonNullValues = [];
    allNonNullValues.addAll(allValues);

    if (allNonNullValues.isNotEmpty) {
      double tempMinValue = 0.0;
      double tempMaxValue = 0.0;

      tempMinValue = allNonNullValues
          .map((value) => value)
          .reduce((value, element) => value! < element! ? value : element)!;

      tempMaxValue = allNonNullValues
          .map((value) => value)
          .reduce((value, element) => value! > element! ? value : element)!;

      if (allMinYAxisValues.isNotEmpty) {
        _minValue = allMinYAxisValues
            .map((value) => value)
            .reduce((value, element) => value < element ? value : element);
      } else {
        _minValue = getMinimumYAxisValue(
          tempMaxValue: tempMaxValue,
          tempMinValue: tempMinValue,
        );
      }

      if (allMaxYAxisValues.isNotEmpty) {
        _maxValue = allMaxYAxisValues
            .map((value) => value)
            .reduce((value, element) => value > element ? value : element);
      } else {
        _maxValue = getMaximumYAxisValue(
          tempMaxValue: tempMaxValue,
          tempMinValue: tempMinValue,
        );
      }
    } else {
      if (allMinYAxisValues.isNotEmpty) {
        _minValue = allMinYAxisValues
            .map((value) => value)
            .reduce((value, element) => value < element ? value : element);
      } else {
        _minValue = 0.0;
      }

      if (allMaxYAxisValues.isNotEmpty) {
        _maxValue = allMaxYAxisValues
            .map((value) => value)
            .reduce((value, element) => value > element ? value : element);
      } else {
        _maxValue = 10.0;
      }
    }
  }

  void setMinValueAndMaxValueForMultipleYAxis() {

    // 전체 데이터를 싹 다 가지고 온다.
    List<double?> allValues = _lineSeriesXCollection
        .expand((lineSeries) => lineSeries.dataMap.values)
        .toList();

    allValues.removeWhere((element) => element == null); // null 인건 전체 삭제.

    List<double?> allNonNullValues = [];
    allNonNullValues.addAll(allValues);

    if (allNonNullValues.isNotEmpty) { // null 이 아니면 실행
      for (LineSeriesX lineSeries in _lineSeriesXCollection) { // 전체 데이터 for 문 돌리기
        List<double?> values = lineSeries.dataMap.values.toList();

        values.removeWhere((element) => element == null); // null 제거

        List<double?> nonNullValues = [];
        nonNullValues.addAll(values);

        double tempMinValue = 0.0;
        double tempMaxValue = 0.0;

        if (nonNullValues.isNotEmpty) {
          tempMinValue = nonNullValues // 최솟값 구하기
              .map((value) => value)
              .reduce((value, element) => value! < element! ? value : element)!;

          tempMaxValue = nonNullValues // 최댓값 구하기
              .map((value) => value)
              .reduce((value, element) => value! > element! ? value : element)!;
        }

        if (lineSeries.minYAxisValue != null) {
          _minValues.add(lineSeries.minYAxisValue!);
        } else {
          double minValue = getMinimumYAxisValue(
            tempMaxValue: tempMaxValue,
            tempMinValue: tempMinValue,
          );
          _minValues.add(minValue);
        }

        if (lineSeries.maxYAxisValue != null) {
          _maxValues.add(lineSeries.maxYAxisValue!);
        } else { // else 면 최댓값을 구한다
          double maxValue = getMaximumYAxisValue(
            tempMaxValue: tempMaxValue,
            tempMinValue: tempMinValue,
          );
          _maxValues.add(maxValue);
        }
      }
    } else {
      for (LineSeriesX lineSeries in _lineSeriesXCollection) {
        if (lineSeries.minYAxisValue != null) {
          _minValues.add(lineSeries.minYAxisValue!);
        } else {
          _minValues.add(0.0);
        }

        if (lineSeries.maxYAxisValue != null) {
          _maxValues.add(lineSeries.maxYAxisValue!);
        } else {
          _maxValues.add(10.0);
        }
      }
    }
  }

  void setMinDateAndMaxDate() {

    // 전체 데이터를 가져와서 시간 별로 정리한다
    List<DateTime> allDateTimes = _lineSeriesXCollection
        .expand((lineSeries) => lineSeries.dataMap.keys)
        .toList();

    if (allDateTimes.isNotEmpty) {
      // 최소 시간을 구한다 - 최초시간
      _minDate = allDateTimes.map((dateTime) => dateTime).reduce(
          (value, element) => value.isBefore(element) ? value : element);

      // 최대 시간을 구한다 - 최대시간
      _maxDate = allDateTimes
          .map((dateTime) => dateTime)
          .reduce((value, element) => value.isAfter(element) ? value : element);
    } else {
      _minDate = null;
      _maxDate = null;
    }
  }

  void setXRangeAndYRange() {
    if (_minDate != null && _maxDate != null) {
      _xRange = _maxDate!.difference(_minDate!).inSeconds.toDouble();
    } else {
      _xRange = 0.0;
    }

    _yRange = _maxValue - _minValue;
  }

  void setXRangeAndYRangeForMultipleYAxis() {
    if (_minDate != null && _maxDate != null) {
      _xRange = _maxDate!.difference(_minDate!).inSeconds.toDouble();
    } else {
      _xRange = 0.0;
    }

    for (int i = 0; i < _lineSeriesXCollection.length; i++) {
      double yRanges = _maxValues[i] - _minValues[i];
      _yRanges.add(yRanges);
    }
  }

  @override
  void initState() {
    super.initState();
    // 시작할때 셋팅하고 시작 시파꺼 존네 복잡하네
    _lineSeriesXCollection = _getLineSeriesXCollection();

    _longestLineSeriesX = _lineSeriesXCollection // 전체 데이터 전처리 과정
        .map((lineSeriesX) => lineSeriesX)
        .reduce((value, element) =>
            value.dataList.length > element.dataList.length ? value : element);

    if (widget.showMultipleYAxises) {
      setMinValueAndMaxValueForMultipleYAxis();
      setMinDateAndMaxDate();
      setXRangeAndYRangeForMultipleYAxis();
    } else {
      setMinValueAndMaxValue();
      setMinDateAndMaxDate();
      setXRangeAndYRange();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 비율 계산
    double widgetWidth = MediaQuery.of(context).size.width;
    double widgetHeight = 200;

    double calculateOffsetX(
      double newScale,
      double focusOnScreen,
    ) {

      double originalTotalWidth = _scale * widgetWidth;
      double newTotalWidth = newScale * widgetWidth;

      double originalRatioInGraph =
          (_offset.abs() + focusOnScreen) / originalTotalWidth;

      double newLocationInGraph = originalRatioInGraph * newTotalWidth;

      return focusOnScreen - newLocationInGraph;
    }

    updateScaleAndScrolling(double newScale, double focusX,
        {double extraX = 0.0}) {
      var widgetWidth = context.size!.width;

      newScale = newScale.clamp(1.0, 30.0);

      double left = calculateOffsetX(newScale, focusX);
      print('left: $left');

      left += extraX;

      double newOffsetX = left.clamp((newScale - 1) * -widgetWidth, 0.0);

      setState(() {
        _scale = newScale;
        _offset = newOffsetX;
      });
    }

    return GestureDetector(
      onScaleStart: (details) { // 화면과 접촉하는 포인터는 초점을 설정하고 1.0의 초기 규모.
        _focalPointX = details.focalPoint.dx; // 해당 클릭시 각 value 값을 띄어주는 부분

        _lastScaleValue = _scale;

        _lastUpdateFocalPointX = details.focalPoint.dx;
      },
      onScaleUpdate: (details) { // 화면에 닿은 포인터가 새로운 초점을 나타냅니다. 및/또는 규모.
        double newScale = (_lastScaleValue * details.scale);

        _deltaFocalPointX = (details.focalPoint.dx - _lastUpdateFocalPointX);
        _lastUpdateFocalPointX = details.focalPoint.dx;

        updateScaleAndScrolling(newScale, _focalPointX,
            extraX: _deltaFocalPointX);
      },
      onScaleEnd: (details) {},
      onLongPressMoveUpdate: (details) { //기본 버튼을 길게 누른 후 포인터를 드래그하여 이동.
        setState(() {
          _longPressX = details.localPosition.dx - _leftOffset;
        });
      },
      onLongPressEnd: (details) {
        setState(() {
          _showTooltip = false;
        });
      },
      onLongPressStart: (details) {
        setState(() {
          _showTooltip = true;
          _longPressX = details.localPosition.dx - _leftOffset;
        });
      },
      child: Column(
        children: [
          widget.title.isNotEmpty
              ? Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : Container(),
          CustomPaint(
            size: Size(
              widgetWidth,
              widgetHeight,
            ),
            painter: LineChartPainter(
              lineSeriesXCollection: _lineSeriesXCollection, // 전체 데이터를 전처리 후 넣어준다
              longestLineSeriesX: _longestLineSeriesX, // 좌측이 되는 기준
              showTooltip: _showTooltip,
              longPressX: _longPressX,
              leftOffset: _leftOffset,
              rightOffset: widget.showMultipleYAxises
                  ? _rightOffset +
                      (widget.lineSeriesCollection.length - 1) *
                          40
                  : _rightOffset,
              offset: _offset,
              scale: _scale,
              minValue: _minValue, // 최솟값
              maxValue: _maxValue, // 최댓값
              minDate: _minDate, // 최소 날짜
              maxDate: _maxDate, // 최대 날짜
              xRange: _xRange,
              yRange: _yRange,
              showMultipleYAxises: widget.showMultipleYAxises,
              minValues: _minValues, // 최소 값 각 마다 가지고 옴
              maxValues: _maxValues, // 최대 값 각 마다 가지고 옴
              yRanges: _yRanges,
            ),
          ),
          const SizedBox(
            height: 40.0,
          ),
          widget.showLegend
              ? Legend(
                  lineSeriesXCollection: _lineSeriesXCollection,
                )
              : Container(),
        ],
      ),
    );
  }
}
