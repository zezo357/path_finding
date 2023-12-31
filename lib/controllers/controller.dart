import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_finding/models/models.dart';

class GridController {
  // Singleton instance, initialized immediately
  static final GridController _instance = GridController._internal();

  // Factory constructor
  factory GridController() {
    return _instance;
  }

  // Private constructor
  GridController._internal() {
    _onInit();
  }

  // Replace RxBool with ValueNotifier
  final ValueNotifier<bool> mouseClicked = ValueNotifier(false);
  final ValueNotifier<bool> findingPath = ValueNotifier(false);

  late List<List<ValueNotifier<BlockState>>> matrix;
  late int rows;
  late int columns;
  CursorType cursorType = CursorType.wall;

  void _onInit() {
    createMatrix(25, 25);
    setRandomStartAndEndBlocks();
  }

  Color fillColor(int row, int column) {
    final state = matrix[row][column].value;
    return getFillColorFromState(state);
  }

  List<List<BlockState>> getMatrixValues() {
    final List<List<BlockState>> matrixValues = [];
    for (final row in matrix) {
      final List<BlockState> rowValues = [];
      for (final blockState in row) {
        rowValues.add(blockState.value);
      }
      matrixValues.add(rowValues);
    }
    return matrixValues;
  }

  Color getFillColorFromState(BlockState state) {
    switch (state) {
      case BlockState.none:
        return Colors.white;
      case BlockState.wall:
        return Colors.black;
      case BlockState.visited:
        return Colors.grey;
      case BlockState.path:
        return Colors.blue;
      case BlockState.start:
        return Colors.green;
      case BlockState.end:
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  set isMouseClicked(bool value) {
    mouseClicked.value = value;
  }

  bool get isMouseClicked {
    return mouseClicked.value;
  }

  bool get isChangingWallStateAllowed {
    return mouseClicked.value && !findingPath.value;
  }

  void updateBlockState(int row, int column) {
    if (rows < 0 || columns < 0 || row >= rows || column >= columns) {
      print("out of bounds");
      return;
    }
    if (isChangingWallStateAllowed) {
      final currentBlockState = matrix[row][column].value;
      BlockState newBlockState = currentBlockState;

      switch (cursorType) {
        case CursorType.start:
          newBlockState = BlockState.start;
          resetStartPoint(); // Reset any existing start point
          break;
        case CursorType.end:
          newBlockState = BlockState.end;
          resetEndPoint(); // Reset any existing end point
          break;
        case CursorType.wall:
          newBlockState = BlockState.wall;
        case CursorType.eraser:
          if (currentBlockState == BlockState.wall) {
            newBlockState = BlockState.none;
          }
        case CursorType.none:
        default:
          break;
      }

      matrix[row][column].value = newBlockState;
    }
  }

  void setStartPoint(int row, int column) {
    if (cursorType == CursorType.start) {
      // Reset existing start point if any
      resetStartPoint();

      // Set the new start point
      matrix[row][column].value = BlockState.start;
    }
  }

  void setEndPoint(int row, int column) {
    if (cursorType == CursorType.end) {
      // Reset existing end point if any
      resetEndPoint();

      // Set the new end point
      matrix[row][column].value = BlockState.end;
    }
  }

  void resetStartPoint() {
    for (final row in matrix) {
      for (final blockState in row) {
        if (blockState.value == BlockState.start) {
          blockState.value = BlockState.none;
          return; // Assuming there's only one start point, exit after resetting
        }
      }
    }
  }

  void resetEndPoint() {
    for (final row in matrix) {
      for (final blockState in row) {
        if (blockState.value == BlockState.end) {
          blockState.value = BlockState.none;
          return; // Assuming there's only one end point, exit after resetting
        }
      }
    }
  }

  void createMatrix(int rows, int columns) {
    this.rows = rows;
    this.columns = columns;

    matrix = List.generate(
      rows,
      (_) => List<ValueNotifier<BlockState>>.generate(
        columns,
        (_) => ValueNotifier<BlockState>(BlockState.none),
      ),
    );
  }

  void resetMatrix() {
    // Reset any existing visited path
    for (int row = 0; row < matrix.length; row++) {
      for (int col = 0; col < matrix[row].length; col++) {
        if (matrix[row][col].value == BlockState.visited ||
            matrix[row][col].value == BlockState.path) {
          matrix[row][col].value = BlockState.none;
        }
      }
    }
  }

  void setRandomStartAndEndBlocks() {
    // Create an instance of the Random class
    final Random random = Random();

    // Generate a random row number for the start and end nodes
    final int startRow = random.nextInt(rows);
    final int endRow = random.nextInt(rows);

    // Generate a random column number for the start and end nodes
    final int startCol =
        random.nextInt(columns ~/ 2); // start node on the left half
    final int endCol = random.nextInt(columns ~/ 2) +
        columns ~/ 2; // end node on the right half

    // Set the start node
    matrix[startRow][startCol].value = BlockState.start;

    // Set the end node
    matrix[endRow][endCol].value = BlockState.end;
  }

  ValueNotifier<BlockState> getRxBlockState(int row, int column) {
    return matrix[row][column];
  }

  Future<void> applyAlgorithmResult(AlgorithmResult result,
      {Duration timeBetweenChanges = const Duration(milliseconds: 20)}) async {
    final List<Change> changes = result.changes;
    final AlgorithmPath? path = result.path;
    resetMatrix();

    // Apply the changes to the matrix
    for (final change in changes) {
      final int row = change.row;
      final int column = change.column;
      final BlockState newState = change.newState;

      // Skip changes if it's the start or end point
      if (matrix[row][column].value == BlockState.start ||
          matrix[row][column].value == BlockState.end) {
        continue;
      }

      matrix[row][column].value = newState;
      await Future.delayed(timeBetweenChanges);
    }

    // Update the end path
    await updateEndPath(path);
  }

  Future<void> updateEndPath(AlgorithmPath? path) async {
    if (path == null) {
      throw Exception("Did not find end path");
    }

    // Apply the new end path
    for (int i = 0; i < path.rows.length; i++) {
      final row = path.rows[i];
      final col = path.columns[i];
      // Skip changes if it's the start or end point
      if (matrix[row][col].value == BlockState.start ||
          matrix[row][col].value == BlockState.end) {
        continue;
      }
      // print("path $row,$col");

      matrix[row][col].value = BlockState.path;
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }
}
