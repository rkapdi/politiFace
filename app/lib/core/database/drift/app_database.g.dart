// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GovNodesTable extends GovNodes with TableInfo<$GovNodesTable, GovNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GovNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _governmentIdMeta =
      const VerificationMeta('governmentId');
  @override
  late final GeneratedColumn<String> governmentId = GeneratedColumn<String>(
      'government_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _externalIdMeta =
      const VerificationMeta('externalId');
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
      'external_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shortNameMeta =
      const VerificationMeta('shortName');
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
      'short_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nodeTypeMeta =
      const VerificationMeta('nodeType');
  @override
  late final GeneratedColumn<String> nodeType = GeneratedColumn<String>(
      'node_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isHeadOfStateMeta =
      const VerificationMeta('isHeadOfState');
  @override
  late final GeneratedColumn<bool> isHeadOfState = GeneratedColumn<bool>(
      'is_head_of_state', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_head_of_state" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isHeadOfGovtMeta =
      const VerificationMeta('isHeadOfGovt');
  @override
  late final GeneratedColumn<bool> isHeadOfGovt = GeneratedColumn<bool>(
      'is_head_of_govt', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_head_of_govt" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isElectedMeta =
      const VerificationMeta('isElected');
  @override
  late final GeneratedColumn<bool> isElected = GeneratedColumn<bool>(
      'is_elected', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_elected" IN (0, 1))'));
  static const VerificationMeta _mapXMeta = const VerificationMeta('mapX');
  @override
  late final GeneratedColumn<double> mapX = GeneratedColumn<double>(
      'map_x', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mapYMeta = const VerificationMeta('mapY');
  @override
  late final GeneratedColumn<double> mapY = GeneratedColumn<double>(
      'map_y', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mapWidthMeta =
      const VerificationMeta('mapWidth');
  @override
  late final GeneratedColumn<double> mapWidth = GeneratedColumn<double>(
      'map_width', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mapHeightMeta =
      const VerificationMeta('mapHeight');
  @override
  late final GeneratedColumn<double> mapHeight = GeneratedColumn<double>(
      'map_height', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _mapShapeMeta =
      const VerificationMeta('mapShape');
  @override
  late final GeneratedColumn<String> mapShape = GeneratedColumn<String>(
      'map_shape', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('rectangle'));
  static const VerificationMeta _mapIconMeta =
      const VerificationMeta('mapIcon');
  @override
  late final GeneratedColumn<String> mapIcon = GeneratedColumn<String>(
      'map_icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mapColorMeta =
      const VerificationMeta('mapColor');
  @override
  late final GeneratedColumn<String> mapColor = GeneratedColumn<String>(
      'map_color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mapLabelPosMeta =
      const VerificationMeta('mapLabelPos');
  @override
  late final GeneratedColumn<String> mapLabelPos = GeneratedColumn<String>(
      'map_label_pos', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('bottom'));
  static const VerificationMeta _tierOrderMeta =
      const VerificationMeta('tierOrder');
  @override
  late final GeneratedColumn<int> tierOrder = GeneratedColumn<int>(
      'tier_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unlockRequiresMeta =
      const VerificationMeta('unlockRequires');
  @override
  late final GeneratedColumn<String> unlockRequires = GeneratedColumn<String>(
      'unlock_requires', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        governmentId,
        externalId,
        name,
        shortName,
        description,
        nodeType,
        isHeadOfState,
        isHeadOfGovt,
        isElected,
        mapX,
        mapY,
        mapWidth,
        mapHeight,
        mapShape,
        mapIcon,
        mapColor,
        mapLabelPos,
        tierOrder,
        unlockRequires,
        isActive,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gov_nodes';
  @override
  VerificationContext validateIntegrity(Insertable<GovNode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('government_id')) {
      context.handle(
          _governmentIdMeta,
          governmentId.isAcceptableOrUnknown(
              data['government_id']!, _governmentIdMeta));
    } else if (isInserting) {
      context.missing(_governmentIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
          _externalIdMeta,
          externalId.isAcceptableOrUnknown(
              data['external_id']!, _externalIdMeta));
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(_shortNameMeta,
          shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('node_type')) {
      context.handle(_nodeTypeMeta,
          nodeType.isAcceptableOrUnknown(data['node_type']!, _nodeTypeMeta));
    } else if (isInserting) {
      context.missing(_nodeTypeMeta);
    }
    if (data.containsKey('is_head_of_state')) {
      context.handle(
          _isHeadOfStateMeta,
          isHeadOfState.isAcceptableOrUnknown(
              data['is_head_of_state']!, _isHeadOfStateMeta));
    }
    if (data.containsKey('is_head_of_govt')) {
      context.handle(
          _isHeadOfGovtMeta,
          isHeadOfGovt.isAcceptableOrUnknown(
              data['is_head_of_govt']!, _isHeadOfGovtMeta));
    }
    if (data.containsKey('is_elected')) {
      context.handle(_isElectedMeta,
          isElected.isAcceptableOrUnknown(data['is_elected']!, _isElectedMeta));
    }
    if (data.containsKey('map_x')) {
      context.handle(
          _mapXMeta, mapX.isAcceptableOrUnknown(data['map_x']!, _mapXMeta));
    }
    if (data.containsKey('map_y')) {
      context.handle(
          _mapYMeta, mapY.isAcceptableOrUnknown(data['map_y']!, _mapYMeta));
    }
    if (data.containsKey('map_width')) {
      context.handle(_mapWidthMeta,
          mapWidth.isAcceptableOrUnknown(data['map_width']!, _mapWidthMeta));
    }
    if (data.containsKey('map_height')) {
      context.handle(_mapHeightMeta,
          mapHeight.isAcceptableOrUnknown(data['map_height']!, _mapHeightMeta));
    }
    if (data.containsKey('map_shape')) {
      context.handle(_mapShapeMeta,
          mapShape.isAcceptableOrUnknown(data['map_shape']!, _mapShapeMeta));
    }
    if (data.containsKey('map_icon')) {
      context.handle(_mapIconMeta,
          mapIcon.isAcceptableOrUnknown(data['map_icon']!, _mapIconMeta));
    }
    if (data.containsKey('map_color')) {
      context.handle(_mapColorMeta,
          mapColor.isAcceptableOrUnknown(data['map_color']!, _mapColorMeta));
    }
    if (data.containsKey('map_label_pos')) {
      context.handle(
          _mapLabelPosMeta,
          mapLabelPos.isAcceptableOrUnknown(
              data['map_label_pos']!, _mapLabelPosMeta));
    }
    if (data.containsKey('tier_order')) {
      context.handle(_tierOrderMeta,
          tierOrder.isAcceptableOrUnknown(data['tier_order']!, _tierOrderMeta));
    } else if (isInserting) {
      context.missing(_tierOrderMeta);
    }
    if (data.containsKey('unlock_requires')) {
      context.handle(
          _unlockRequiresMeta,
          unlockRequires.isAcceptableOrUnknown(
              data['unlock_requires']!, _unlockRequiresMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GovNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GovNode(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      governmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}government_id'])!,
      externalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}external_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      shortName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}short_name']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      nodeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_type'])!,
      isHeadOfState: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_head_of_state'])!,
      isHeadOfGovt: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_head_of_govt'])!,
      isElected: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_elected']),
      mapX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}map_x']),
      mapY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}map_y']),
      mapWidth: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}map_width']),
      mapHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}map_height']),
      mapShape: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}map_shape'])!,
      mapIcon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}map_icon']),
      mapColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}map_color']),
      mapLabelPos: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}map_label_pos'])!,
      tierOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tier_order'])!,
      unlockRequires: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}unlock_requires'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $GovNodesTable createAlias(String alias) {
    return $GovNodesTable(attachedDatabase, alias);
  }
}

class GovNode extends DataClass implements Insertable<GovNode> {
  final String id;
  final String governmentId;
  final String externalId;
  final String name;
  final String? shortName;
  final String? description;
  final String nodeType;
  final bool isHeadOfState;
  final bool isHeadOfGovt;
  final bool? isElected;
  final double? mapX;
  final double? mapY;
  final double? mapWidth;
  final double? mapHeight;
  final String mapShape;
  final String? mapIcon;
  final String? mapColor;
  final String mapLabelPos;
  final int tierOrder;
  final String unlockRequires;
  final bool isActive;
  final int sortOrder;
  const GovNode(
      {required this.id,
      required this.governmentId,
      required this.externalId,
      required this.name,
      this.shortName,
      this.description,
      required this.nodeType,
      required this.isHeadOfState,
      required this.isHeadOfGovt,
      this.isElected,
      this.mapX,
      this.mapY,
      this.mapWidth,
      this.mapHeight,
      required this.mapShape,
      this.mapIcon,
      this.mapColor,
      required this.mapLabelPos,
      required this.tierOrder,
      required this.unlockRequires,
      required this.isActive,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['government_id'] = Variable<String>(governmentId);
    map['external_id'] = Variable<String>(externalId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || shortName != null) {
      map['short_name'] = Variable<String>(shortName);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['node_type'] = Variable<String>(nodeType);
    map['is_head_of_state'] = Variable<bool>(isHeadOfState);
    map['is_head_of_govt'] = Variable<bool>(isHeadOfGovt);
    if (!nullToAbsent || isElected != null) {
      map['is_elected'] = Variable<bool>(isElected);
    }
    if (!nullToAbsent || mapX != null) {
      map['map_x'] = Variable<double>(mapX);
    }
    if (!nullToAbsent || mapY != null) {
      map['map_y'] = Variable<double>(mapY);
    }
    if (!nullToAbsent || mapWidth != null) {
      map['map_width'] = Variable<double>(mapWidth);
    }
    if (!nullToAbsent || mapHeight != null) {
      map['map_height'] = Variable<double>(mapHeight);
    }
    map['map_shape'] = Variable<String>(mapShape);
    if (!nullToAbsent || mapIcon != null) {
      map['map_icon'] = Variable<String>(mapIcon);
    }
    if (!nullToAbsent || mapColor != null) {
      map['map_color'] = Variable<String>(mapColor);
    }
    map['map_label_pos'] = Variable<String>(mapLabelPos);
    map['tier_order'] = Variable<int>(tierOrder);
    map['unlock_requires'] = Variable<String>(unlockRequires);
    map['is_active'] = Variable<bool>(isActive);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  GovNodesCompanion toCompanion(bool nullToAbsent) {
    return GovNodesCompanion(
      id: Value(id),
      governmentId: Value(governmentId),
      externalId: Value(externalId),
      name: Value(name),
      shortName: shortName == null && nullToAbsent
          ? const Value.absent()
          : Value(shortName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      nodeType: Value(nodeType),
      isHeadOfState: Value(isHeadOfState),
      isHeadOfGovt: Value(isHeadOfGovt),
      isElected: isElected == null && nullToAbsent
          ? const Value.absent()
          : Value(isElected),
      mapX: mapX == null && nullToAbsent ? const Value.absent() : Value(mapX),
      mapY: mapY == null && nullToAbsent ? const Value.absent() : Value(mapY),
      mapWidth: mapWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(mapWidth),
      mapHeight: mapHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(mapHeight),
      mapShape: Value(mapShape),
      mapIcon: mapIcon == null && nullToAbsent
          ? const Value.absent()
          : Value(mapIcon),
      mapColor: mapColor == null && nullToAbsent
          ? const Value.absent()
          : Value(mapColor),
      mapLabelPos: Value(mapLabelPos),
      tierOrder: Value(tierOrder),
      unlockRequires: Value(unlockRequires),
      isActive: Value(isActive),
      sortOrder: Value(sortOrder),
    );
  }

  factory GovNode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GovNode(
      id: serializer.fromJson<String>(json['id']),
      governmentId: serializer.fromJson<String>(json['governmentId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      name: serializer.fromJson<String>(json['name']),
      shortName: serializer.fromJson<String?>(json['shortName']),
      description: serializer.fromJson<String?>(json['description']),
      nodeType: serializer.fromJson<String>(json['nodeType']),
      isHeadOfState: serializer.fromJson<bool>(json['isHeadOfState']),
      isHeadOfGovt: serializer.fromJson<bool>(json['isHeadOfGovt']),
      isElected: serializer.fromJson<bool?>(json['isElected']),
      mapX: serializer.fromJson<double?>(json['mapX']),
      mapY: serializer.fromJson<double?>(json['mapY']),
      mapWidth: serializer.fromJson<double?>(json['mapWidth']),
      mapHeight: serializer.fromJson<double?>(json['mapHeight']),
      mapShape: serializer.fromJson<String>(json['mapShape']),
      mapIcon: serializer.fromJson<String?>(json['mapIcon']),
      mapColor: serializer.fromJson<String?>(json['mapColor']),
      mapLabelPos: serializer.fromJson<String>(json['mapLabelPos']),
      tierOrder: serializer.fromJson<int>(json['tierOrder']),
      unlockRequires: serializer.fromJson<String>(json['unlockRequires']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'governmentId': serializer.toJson<String>(governmentId),
      'externalId': serializer.toJson<String>(externalId),
      'name': serializer.toJson<String>(name),
      'shortName': serializer.toJson<String?>(shortName),
      'description': serializer.toJson<String?>(description),
      'nodeType': serializer.toJson<String>(nodeType),
      'isHeadOfState': serializer.toJson<bool>(isHeadOfState),
      'isHeadOfGovt': serializer.toJson<bool>(isHeadOfGovt),
      'isElected': serializer.toJson<bool?>(isElected),
      'mapX': serializer.toJson<double?>(mapX),
      'mapY': serializer.toJson<double?>(mapY),
      'mapWidth': serializer.toJson<double?>(mapWidth),
      'mapHeight': serializer.toJson<double?>(mapHeight),
      'mapShape': serializer.toJson<String>(mapShape),
      'mapIcon': serializer.toJson<String?>(mapIcon),
      'mapColor': serializer.toJson<String?>(mapColor),
      'mapLabelPos': serializer.toJson<String>(mapLabelPos),
      'tierOrder': serializer.toJson<int>(tierOrder),
      'unlockRequires': serializer.toJson<String>(unlockRequires),
      'isActive': serializer.toJson<bool>(isActive),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  GovNode copyWith(
          {String? id,
          String? governmentId,
          String? externalId,
          String? name,
          Value<String?> shortName = const Value.absent(),
          Value<String?> description = const Value.absent(),
          String? nodeType,
          bool? isHeadOfState,
          bool? isHeadOfGovt,
          Value<bool?> isElected = const Value.absent(),
          Value<double?> mapX = const Value.absent(),
          Value<double?> mapY = const Value.absent(),
          Value<double?> mapWidth = const Value.absent(),
          Value<double?> mapHeight = const Value.absent(),
          String? mapShape,
          Value<String?> mapIcon = const Value.absent(),
          Value<String?> mapColor = const Value.absent(),
          String? mapLabelPos,
          int? tierOrder,
          String? unlockRequires,
          bool? isActive,
          int? sortOrder}) =>
      GovNode(
        id: id ?? this.id,
        governmentId: governmentId ?? this.governmentId,
        externalId: externalId ?? this.externalId,
        name: name ?? this.name,
        shortName: shortName.present ? shortName.value : this.shortName,
        description: description.present ? description.value : this.description,
        nodeType: nodeType ?? this.nodeType,
        isHeadOfState: isHeadOfState ?? this.isHeadOfState,
        isHeadOfGovt: isHeadOfGovt ?? this.isHeadOfGovt,
        isElected: isElected.present ? isElected.value : this.isElected,
        mapX: mapX.present ? mapX.value : this.mapX,
        mapY: mapY.present ? mapY.value : this.mapY,
        mapWidth: mapWidth.present ? mapWidth.value : this.mapWidth,
        mapHeight: mapHeight.present ? mapHeight.value : this.mapHeight,
        mapShape: mapShape ?? this.mapShape,
        mapIcon: mapIcon.present ? mapIcon.value : this.mapIcon,
        mapColor: mapColor.present ? mapColor.value : this.mapColor,
        mapLabelPos: mapLabelPos ?? this.mapLabelPos,
        tierOrder: tierOrder ?? this.tierOrder,
        unlockRequires: unlockRequires ?? this.unlockRequires,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  GovNode copyWithCompanion(GovNodesCompanion data) {
    return GovNode(
      id: data.id.present ? data.id.value : this.id,
      governmentId: data.governmentId.present
          ? data.governmentId.value
          : this.governmentId,
      externalId:
          data.externalId.present ? data.externalId.value : this.externalId,
      name: data.name.present ? data.name.value : this.name,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      description:
          data.description.present ? data.description.value : this.description,
      nodeType: data.nodeType.present ? data.nodeType.value : this.nodeType,
      isHeadOfState: data.isHeadOfState.present
          ? data.isHeadOfState.value
          : this.isHeadOfState,
      isHeadOfGovt: data.isHeadOfGovt.present
          ? data.isHeadOfGovt.value
          : this.isHeadOfGovt,
      isElected: data.isElected.present ? data.isElected.value : this.isElected,
      mapX: data.mapX.present ? data.mapX.value : this.mapX,
      mapY: data.mapY.present ? data.mapY.value : this.mapY,
      mapWidth: data.mapWidth.present ? data.mapWidth.value : this.mapWidth,
      mapHeight: data.mapHeight.present ? data.mapHeight.value : this.mapHeight,
      mapShape: data.mapShape.present ? data.mapShape.value : this.mapShape,
      mapIcon: data.mapIcon.present ? data.mapIcon.value : this.mapIcon,
      mapColor: data.mapColor.present ? data.mapColor.value : this.mapColor,
      mapLabelPos:
          data.mapLabelPos.present ? data.mapLabelPos.value : this.mapLabelPos,
      tierOrder: data.tierOrder.present ? data.tierOrder.value : this.tierOrder,
      unlockRequires: data.unlockRequires.present
          ? data.unlockRequires.value
          : this.unlockRequires,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GovNode(')
          ..write('id: $id, ')
          ..write('governmentId: $governmentId, ')
          ..write('externalId: $externalId, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('description: $description, ')
          ..write('nodeType: $nodeType, ')
          ..write('isHeadOfState: $isHeadOfState, ')
          ..write('isHeadOfGovt: $isHeadOfGovt, ')
          ..write('isElected: $isElected, ')
          ..write('mapX: $mapX, ')
          ..write('mapY: $mapY, ')
          ..write('mapWidth: $mapWidth, ')
          ..write('mapHeight: $mapHeight, ')
          ..write('mapShape: $mapShape, ')
          ..write('mapIcon: $mapIcon, ')
          ..write('mapColor: $mapColor, ')
          ..write('mapLabelPos: $mapLabelPos, ')
          ..write('tierOrder: $tierOrder, ')
          ..write('unlockRequires: $unlockRequires, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        governmentId,
        externalId,
        name,
        shortName,
        description,
        nodeType,
        isHeadOfState,
        isHeadOfGovt,
        isElected,
        mapX,
        mapY,
        mapWidth,
        mapHeight,
        mapShape,
        mapIcon,
        mapColor,
        mapLabelPos,
        tierOrder,
        unlockRequires,
        isActive,
        sortOrder
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GovNode &&
          other.id == this.id &&
          other.governmentId == this.governmentId &&
          other.externalId == this.externalId &&
          other.name == this.name &&
          other.shortName == this.shortName &&
          other.description == this.description &&
          other.nodeType == this.nodeType &&
          other.isHeadOfState == this.isHeadOfState &&
          other.isHeadOfGovt == this.isHeadOfGovt &&
          other.isElected == this.isElected &&
          other.mapX == this.mapX &&
          other.mapY == this.mapY &&
          other.mapWidth == this.mapWidth &&
          other.mapHeight == this.mapHeight &&
          other.mapShape == this.mapShape &&
          other.mapIcon == this.mapIcon &&
          other.mapColor == this.mapColor &&
          other.mapLabelPos == this.mapLabelPos &&
          other.tierOrder == this.tierOrder &&
          other.unlockRequires == this.unlockRequires &&
          other.isActive == this.isActive &&
          other.sortOrder == this.sortOrder);
}

class GovNodesCompanion extends UpdateCompanion<GovNode> {
  final Value<String> id;
  final Value<String> governmentId;
  final Value<String> externalId;
  final Value<String> name;
  final Value<String?> shortName;
  final Value<String?> description;
  final Value<String> nodeType;
  final Value<bool> isHeadOfState;
  final Value<bool> isHeadOfGovt;
  final Value<bool?> isElected;
  final Value<double?> mapX;
  final Value<double?> mapY;
  final Value<double?> mapWidth;
  final Value<double?> mapHeight;
  final Value<String> mapShape;
  final Value<String?> mapIcon;
  final Value<String?> mapColor;
  final Value<String> mapLabelPos;
  final Value<int> tierOrder;
  final Value<String> unlockRequires;
  final Value<bool> isActive;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GovNodesCompanion({
    this.id = const Value.absent(),
    this.governmentId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.name = const Value.absent(),
    this.shortName = const Value.absent(),
    this.description = const Value.absent(),
    this.nodeType = const Value.absent(),
    this.isHeadOfState = const Value.absent(),
    this.isHeadOfGovt = const Value.absent(),
    this.isElected = const Value.absent(),
    this.mapX = const Value.absent(),
    this.mapY = const Value.absent(),
    this.mapWidth = const Value.absent(),
    this.mapHeight = const Value.absent(),
    this.mapShape = const Value.absent(),
    this.mapIcon = const Value.absent(),
    this.mapColor = const Value.absent(),
    this.mapLabelPos = const Value.absent(),
    this.tierOrder = const Value.absent(),
    this.unlockRequires = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GovNodesCompanion.insert({
    required String id,
    required String governmentId,
    required String externalId,
    required String name,
    this.shortName = const Value.absent(),
    this.description = const Value.absent(),
    required String nodeType,
    this.isHeadOfState = const Value.absent(),
    this.isHeadOfGovt = const Value.absent(),
    this.isElected = const Value.absent(),
    this.mapX = const Value.absent(),
    this.mapY = const Value.absent(),
    this.mapWidth = const Value.absent(),
    this.mapHeight = const Value.absent(),
    this.mapShape = const Value.absent(),
    this.mapIcon = const Value.absent(),
    this.mapColor = const Value.absent(),
    this.mapLabelPos = const Value.absent(),
    required int tierOrder,
    this.unlockRequires = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        governmentId = Value(governmentId),
        externalId = Value(externalId),
        name = Value(name),
        nodeType = Value(nodeType),
        tierOrder = Value(tierOrder);
  static Insertable<GovNode> custom({
    Expression<String>? id,
    Expression<String>? governmentId,
    Expression<String>? externalId,
    Expression<String>? name,
    Expression<String>? shortName,
    Expression<String>? description,
    Expression<String>? nodeType,
    Expression<bool>? isHeadOfState,
    Expression<bool>? isHeadOfGovt,
    Expression<bool>? isElected,
    Expression<double>? mapX,
    Expression<double>? mapY,
    Expression<double>? mapWidth,
    Expression<double>? mapHeight,
    Expression<String>? mapShape,
    Expression<String>? mapIcon,
    Expression<String>? mapColor,
    Expression<String>? mapLabelPos,
    Expression<int>? tierOrder,
    Expression<String>? unlockRequires,
    Expression<bool>? isActive,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (governmentId != null) 'government_id': governmentId,
      if (externalId != null) 'external_id': externalId,
      if (name != null) 'name': name,
      if (shortName != null) 'short_name': shortName,
      if (description != null) 'description': description,
      if (nodeType != null) 'node_type': nodeType,
      if (isHeadOfState != null) 'is_head_of_state': isHeadOfState,
      if (isHeadOfGovt != null) 'is_head_of_govt': isHeadOfGovt,
      if (isElected != null) 'is_elected': isElected,
      if (mapX != null) 'map_x': mapX,
      if (mapY != null) 'map_y': mapY,
      if (mapWidth != null) 'map_width': mapWidth,
      if (mapHeight != null) 'map_height': mapHeight,
      if (mapShape != null) 'map_shape': mapShape,
      if (mapIcon != null) 'map_icon': mapIcon,
      if (mapColor != null) 'map_color': mapColor,
      if (mapLabelPos != null) 'map_label_pos': mapLabelPos,
      if (tierOrder != null) 'tier_order': tierOrder,
      if (unlockRequires != null) 'unlock_requires': unlockRequires,
      if (isActive != null) 'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GovNodesCompanion copyWith(
      {Value<String>? id,
      Value<String>? governmentId,
      Value<String>? externalId,
      Value<String>? name,
      Value<String?>? shortName,
      Value<String?>? description,
      Value<String>? nodeType,
      Value<bool>? isHeadOfState,
      Value<bool>? isHeadOfGovt,
      Value<bool?>? isElected,
      Value<double?>? mapX,
      Value<double?>? mapY,
      Value<double?>? mapWidth,
      Value<double?>? mapHeight,
      Value<String>? mapShape,
      Value<String?>? mapIcon,
      Value<String?>? mapColor,
      Value<String>? mapLabelPos,
      Value<int>? tierOrder,
      Value<String>? unlockRequires,
      Value<bool>? isActive,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return GovNodesCompanion(
      id: id ?? this.id,
      governmentId: governmentId ?? this.governmentId,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      description: description ?? this.description,
      nodeType: nodeType ?? this.nodeType,
      isHeadOfState: isHeadOfState ?? this.isHeadOfState,
      isHeadOfGovt: isHeadOfGovt ?? this.isHeadOfGovt,
      isElected: isElected ?? this.isElected,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      mapWidth: mapWidth ?? this.mapWidth,
      mapHeight: mapHeight ?? this.mapHeight,
      mapShape: mapShape ?? this.mapShape,
      mapIcon: mapIcon ?? this.mapIcon,
      mapColor: mapColor ?? this.mapColor,
      mapLabelPos: mapLabelPos ?? this.mapLabelPos,
      tierOrder: tierOrder ?? this.tierOrder,
      unlockRequires: unlockRequires ?? this.unlockRequires,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (governmentId.present) {
      map['government_id'] = Variable<String>(governmentId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (nodeType.present) {
      map['node_type'] = Variable<String>(nodeType.value);
    }
    if (isHeadOfState.present) {
      map['is_head_of_state'] = Variable<bool>(isHeadOfState.value);
    }
    if (isHeadOfGovt.present) {
      map['is_head_of_govt'] = Variable<bool>(isHeadOfGovt.value);
    }
    if (isElected.present) {
      map['is_elected'] = Variable<bool>(isElected.value);
    }
    if (mapX.present) {
      map['map_x'] = Variable<double>(mapX.value);
    }
    if (mapY.present) {
      map['map_y'] = Variable<double>(mapY.value);
    }
    if (mapWidth.present) {
      map['map_width'] = Variable<double>(mapWidth.value);
    }
    if (mapHeight.present) {
      map['map_height'] = Variable<double>(mapHeight.value);
    }
    if (mapShape.present) {
      map['map_shape'] = Variable<String>(mapShape.value);
    }
    if (mapIcon.present) {
      map['map_icon'] = Variable<String>(mapIcon.value);
    }
    if (mapColor.present) {
      map['map_color'] = Variable<String>(mapColor.value);
    }
    if (mapLabelPos.present) {
      map['map_label_pos'] = Variable<String>(mapLabelPos.value);
    }
    if (tierOrder.present) {
      map['tier_order'] = Variable<int>(tierOrder.value);
    }
    if (unlockRequires.present) {
      map['unlock_requires'] = Variable<String>(unlockRequires.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GovNodesCompanion(')
          ..write('id: $id, ')
          ..write('governmentId: $governmentId, ')
          ..write('externalId: $externalId, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('description: $description, ')
          ..write('nodeType: $nodeType, ')
          ..write('isHeadOfState: $isHeadOfState, ')
          ..write('isHeadOfGovt: $isHeadOfGovt, ')
          ..write('isElected: $isElected, ')
          ..write('mapX: $mapX, ')
          ..write('mapY: $mapY, ')
          ..write('mapWidth: $mapWidth, ')
          ..write('mapHeight: $mapHeight, ')
          ..write('mapShape: $mapShape, ')
          ..write('mapIcon: $mapIcon, ')
          ..write('mapColor: $mapColor, ')
          ..write('mapLabelPos: $mapLabelPos, ')
          ..write('tierOrder: $tierOrder, ')
          ..write('unlockRequires: $unlockRequires, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GovEdgesTable extends GovEdges with TableInfo<$GovEdgesTable, GovEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GovEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _governmentIdMeta =
      const VerificationMeta('governmentId');
  @override
  late final GeneratedColumn<String> governmentId = GeneratedColumn<String>(
      'government_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromNodeIdMeta =
      const VerificationMeta('fromNodeId');
  @override
  late final GeneratedColumn<String> fromNodeId = GeneratedColumn<String>(
      'from_node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toNodeIdMeta =
      const VerificationMeta('toNodeId');
  @override
  late final GeneratedColumn<String> toNodeId = GeneratedColumn<String>(
      'to_node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _relationshipTypeMeta =
      const VerificationMeta('relationshipType');
  @override
  late final GeneratedColumn<String> relationshipType = GeneratedColumn<String>(
      'relationship_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isVisibleOnMapMeta =
      const VerificationMeta('isVisibleOnMap');
  @override
  late final GeneratedColumn<bool> isVisibleOnMap = GeneratedColumn<bool>(
      'is_visible_on_map', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_visible_on_map" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _lineStyleMeta =
      const VerificationMeta('lineStyle');
  @override
  late final GeneratedColumn<String> lineStyle = GeneratedColumn<String>(
      'line_style', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('solid'));
  static const VerificationMeta _lineColorMeta =
      const VerificationMeta('lineColor');
  @override
  late final GeneratedColumn<String> lineColor = GeneratedColumn<String>(
      'line_color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _arrowDirectionMeta =
      const VerificationMeta('arrowDirection');
  @override
  late final GeneratedColumn<String> arrowDirection = GeneratedColumn<String>(
      'arrow_direction', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('to'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        governmentId,
        fromNodeId,
        toNodeId,
        relationshipType,
        description,
        isVisibleOnMap,
        lineStyle,
        lineColor,
        arrowDirection
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gov_edges';
  @override
  VerificationContext validateIntegrity(Insertable<GovEdge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('government_id')) {
      context.handle(
          _governmentIdMeta,
          governmentId.isAcceptableOrUnknown(
              data['government_id']!, _governmentIdMeta));
    } else if (isInserting) {
      context.missing(_governmentIdMeta);
    }
    if (data.containsKey('from_node_id')) {
      context.handle(
          _fromNodeIdMeta,
          fromNodeId.isAcceptableOrUnknown(
              data['from_node_id']!, _fromNodeIdMeta));
    } else if (isInserting) {
      context.missing(_fromNodeIdMeta);
    }
    if (data.containsKey('to_node_id')) {
      context.handle(_toNodeIdMeta,
          toNodeId.isAcceptableOrUnknown(data['to_node_id']!, _toNodeIdMeta));
    } else if (isInserting) {
      context.missing(_toNodeIdMeta);
    }
    if (data.containsKey('relationship_type')) {
      context.handle(
          _relationshipTypeMeta,
          relationshipType.isAcceptableOrUnknown(
              data['relationship_type']!, _relationshipTypeMeta));
    } else if (isInserting) {
      context.missing(_relationshipTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_visible_on_map')) {
      context.handle(
          _isVisibleOnMapMeta,
          isVisibleOnMap.isAcceptableOrUnknown(
              data['is_visible_on_map']!, _isVisibleOnMapMeta));
    }
    if (data.containsKey('line_style')) {
      context.handle(_lineStyleMeta,
          lineStyle.isAcceptableOrUnknown(data['line_style']!, _lineStyleMeta));
    }
    if (data.containsKey('line_color')) {
      context.handle(_lineColorMeta,
          lineColor.isAcceptableOrUnknown(data['line_color']!, _lineColorMeta));
    }
    if (data.containsKey('arrow_direction')) {
      context.handle(
          _arrowDirectionMeta,
          arrowDirection.isAcceptableOrUnknown(
              data['arrow_direction']!, _arrowDirectionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GovEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GovEdge(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      governmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}government_id'])!,
      fromNodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_node_id'])!,
      toNodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_node_id'])!,
      relationshipType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}relationship_type'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isVisibleOnMap: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_visible_on_map'])!,
      lineStyle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_style'])!,
      lineColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_color']),
      arrowDirection: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}arrow_direction'])!,
    );
  }

  @override
  $GovEdgesTable createAlias(String alias) {
    return $GovEdgesTable(attachedDatabase, alias);
  }
}

class GovEdge extends DataClass implements Insertable<GovEdge> {
  final String id;
  final String governmentId;
  final String fromNodeId;
  final String toNodeId;
  final String relationshipType;
  final String? description;
  final bool isVisibleOnMap;
  final String lineStyle;
  final String? lineColor;
  final String arrowDirection;
  const GovEdge(
      {required this.id,
      required this.governmentId,
      required this.fromNodeId,
      required this.toNodeId,
      required this.relationshipType,
      this.description,
      required this.isVisibleOnMap,
      required this.lineStyle,
      this.lineColor,
      required this.arrowDirection});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['government_id'] = Variable<String>(governmentId);
    map['from_node_id'] = Variable<String>(fromNodeId);
    map['to_node_id'] = Variable<String>(toNodeId);
    map['relationship_type'] = Variable<String>(relationshipType);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_visible_on_map'] = Variable<bool>(isVisibleOnMap);
    map['line_style'] = Variable<String>(lineStyle);
    if (!nullToAbsent || lineColor != null) {
      map['line_color'] = Variable<String>(lineColor);
    }
    map['arrow_direction'] = Variable<String>(arrowDirection);
    return map;
  }

  GovEdgesCompanion toCompanion(bool nullToAbsent) {
    return GovEdgesCompanion(
      id: Value(id),
      governmentId: Value(governmentId),
      fromNodeId: Value(fromNodeId),
      toNodeId: Value(toNodeId),
      relationshipType: Value(relationshipType),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isVisibleOnMap: Value(isVisibleOnMap),
      lineStyle: Value(lineStyle),
      lineColor: lineColor == null && nullToAbsent
          ? const Value.absent()
          : Value(lineColor),
      arrowDirection: Value(arrowDirection),
    );
  }

  factory GovEdge.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GovEdge(
      id: serializer.fromJson<String>(json['id']),
      governmentId: serializer.fromJson<String>(json['governmentId']),
      fromNodeId: serializer.fromJson<String>(json['fromNodeId']),
      toNodeId: serializer.fromJson<String>(json['toNodeId']),
      relationshipType: serializer.fromJson<String>(json['relationshipType']),
      description: serializer.fromJson<String?>(json['description']),
      isVisibleOnMap: serializer.fromJson<bool>(json['isVisibleOnMap']),
      lineStyle: serializer.fromJson<String>(json['lineStyle']),
      lineColor: serializer.fromJson<String?>(json['lineColor']),
      arrowDirection: serializer.fromJson<String>(json['arrowDirection']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'governmentId': serializer.toJson<String>(governmentId),
      'fromNodeId': serializer.toJson<String>(fromNodeId),
      'toNodeId': serializer.toJson<String>(toNodeId),
      'relationshipType': serializer.toJson<String>(relationshipType),
      'description': serializer.toJson<String?>(description),
      'isVisibleOnMap': serializer.toJson<bool>(isVisibleOnMap),
      'lineStyle': serializer.toJson<String>(lineStyle),
      'lineColor': serializer.toJson<String?>(lineColor),
      'arrowDirection': serializer.toJson<String>(arrowDirection),
    };
  }

  GovEdge copyWith(
          {String? id,
          String? governmentId,
          String? fromNodeId,
          String? toNodeId,
          String? relationshipType,
          Value<String?> description = const Value.absent(),
          bool? isVisibleOnMap,
          String? lineStyle,
          Value<String?> lineColor = const Value.absent(),
          String? arrowDirection}) =>
      GovEdge(
        id: id ?? this.id,
        governmentId: governmentId ?? this.governmentId,
        fromNodeId: fromNodeId ?? this.fromNodeId,
        toNodeId: toNodeId ?? this.toNodeId,
        relationshipType: relationshipType ?? this.relationshipType,
        description: description.present ? description.value : this.description,
        isVisibleOnMap: isVisibleOnMap ?? this.isVisibleOnMap,
        lineStyle: lineStyle ?? this.lineStyle,
        lineColor: lineColor.present ? lineColor.value : this.lineColor,
        arrowDirection: arrowDirection ?? this.arrowDirection,
      );
  GovEdge copyWithCompanion(GovEdgesCompanion data) {
    return GovEdge(
      id: data.id.present ? data.id.value : this.id,
      governmentId: data.governmentId.present
          ? data.governmentId.value
          : this.governmentId,
      fromNodeId:
          data.fromNodeId.present ? data.fromNodeId.value : this.fromNodeId,
      toNodeId: data.toNodeId.present ? data.toNodeId.value : this.toNodeId,
      relationshipType: data.relationshipType.present
          ? data.relationshipType.value
          : this.relationshipType,
      description:
          data.description.present ? data.description.value : this.description,
      isVisibleOnMap: data.isVisibleOnMap.present
          ? data.isVisibleOnMap.value
          : this.isVisibleOnMap,
      lineStyle: data.lineStyle.present ? data.lineStyle.value : this.lineStyle,
      lineColor: data.lineColor.present ? data.lineColor.value : this.lineColor,
      arrowDirection: data.arrowDirection.present
          ? data.arrowDirection.value
          : this.arrowDirection,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GovEdge(')
          ..write('id: $id, ')
          ..write('governmentId: $governmentId, ')
          ..write('fromNodeId: $fromNodeId, ')
          ..write('toNodeId: $toNodeId, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('description: $description, ')
          ..write('isVisibleOnMap: $isVisibleOnMap, ')
          ..write('lineStyle: $lineStyle, ')
          ..write('lineColor: $lineColor, ')
          ..write('arrowDirection: $arrowDirection')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      governmentId,
      fromNodeId,
      toNodeId,
      relationshipType,
      description,
      isVisibleOnMap,
      lineStyle,
      lineColor,
      arrowDirection);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GovEdge &&
          other.id == this.id &&
          other.governmentId == this.governmentId &&
          other.fromNodeId == this.fromNodeId &&
          other.toNodeId == this.toNodeId &&
          other.relationshipType == this.relationshipType &&
          other.description == this.description &&
          other.isVisibleOnMap == this.isVisibleOnMap &&
          other.lineStyle == this.lineStyle &&
          other.lineColor == this.lineColor &&
          other.arrowDirection == this.arrowDirection);
}

class GovEdgesCompanion extends UpdateCompanion<GovEdge> {
  final Value<String> id;
  final Value<String> governmentId;
  final Value<String> fromNodeId;
  final Value<String> toNodeId;
  final Value<String> relationshipType;
  final Value<String?> description;
  final Value<bool> isVisibleOnMap;
  final Value<String> lineStyle;
  final Value<String?> lineColor;
  final Value<String> arrowDirection;
  final Value<int> rowid;
  const GovEdgesCompanion({
    this.id = const Value.absent(),
    this.governmentId = const Value.absent(),
    this.fromNodeId = const Value.absent(),
    this.toNodeId = const Value.absent(),
    this.relationshipType = const Value.absent(),
    this.description = const Value.absent(),
    this.isVisibleOnMap = const Value.absent(),
    this.lineStyle = const Value.absent(),
    this.lineColor = const Value.absent(),
    this.arrowDirection = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GovEdgesCompanion.insert({
    required String id,
    required String governmentId,
    required String fromNodeId,
    required String toNodeId,
    required String relationshipType,
    this.description = const Value.absent(),
    this.isVisibleOnMap = const Value.absent(),
    this.lineStyle = const Value.absent(),
    this.lineColor = const Value.absent(),
    this.arrowDirection = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        governmentId = Value(governmentId),
        fromNodeId = Value(fromNodeId),
        toNodeId = Value(toNodeId),
        relationshipType = Value(relationshipType);
  static Insertable<GovEdge> custom({
    Expression<String>? id,
    Expression<String>? governmentId,
    Expression<String>? fromNodeId,
    Expression<String>? toNodeId,
    Expression<String>? relationshipType,
    Expression<String>? description,
    Expression<bool>? isVisibleOnMap,
    Expression<String>? lineStyle,
    Expression<String>? lineColor,
    Expression<String>? arrowDirection,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (governmentId != null) 'government_id': governmentId,
      if (fromNodeId != null) 'from_node_id': fromNodeId,
      if (toNodeId != null) 'to_node_id': toNodeId,
      if (relationshipType != null) 'relationship_type': relationshipType,
      if (description != null) 'description': description,
      if (isVisibleOnMap != null) 'is_visible_on_map': isVisibleOnMap,
      if (lineStyle != null) 'line_style': lineStyle,
      if (lineColor != null) 'line_color': lineColor,
      if (arrowDirection != null) 'arrow_direction': arrowDirection,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GovEdgesCompanion copyWith(
      {Value<String>? id,
      Value<String>? governmentId,
      Value<String>? fromNodeId,
      Value<String>? toNodeId,
      Value<String>? relationshipType,
      Value<String?>? description,
      Value<bool>? isVisibleOnMap,
      Value<String>? lineStyle,
      Value<String?>? lineColor,
      Value<String>? arrowDirection,
      Value<int>? rowid}) {
    return GovEdgesCompanion(
      id: id ?? this.id,
      governmentId: governmentId ?? this.governmentId,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      relationshipType: relationshipType ?? this.relationshipType,
      description: description ?? this.description,
      isVisibleOnMap: isVisibleOnMap ?? this.isVisibleOnMap,
      lineStyle: lineStyle ?? this.lineStyle,
      lineColor: lineColor ?? this.lineColor,
      arrowDirection: arrowDirection ?? this.arrowDirection,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (governmentId.present) {
      map['government_id'] = Variable<String>(governmentId.value);
    }
    if (fromNodeId.present) {
      map['from_node_id'] = Variable<String>(fromNodeId.value);
    }
    if (toNodeId.present) {
      map['to_node_id'] = Variable<String>(toNodeId.value);
    }
    if (relationshipType.present) {
      map['relationship_type'] = Variable<String>(relationshipType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isVisibleOnMap.present) {
      map['is_visible_on_map'] = Variable<bool>(isVisibleOnMap.value);
    }
    if (lineStyle.present) {
      map['line_style'] = Variable<String>(lineStyle.value);
    }
    if (lineColor.present) {
      map['line_color'] = Variable<String>(lineColor.value);
    }
    if (arrowDirection.present) {
      map['arrow_direction'] = Variable<String>(arrowDirection.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GovEdgesCompanion(')
          ..write('id: $id, ')
          ..write('governmentId: $governmentId, ')
          ..write('fromNodeId: $fromNodeId, ')
          ..write('toNodeId: $toNodeId, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('description: $description, ')
          ..write('isVisibleOnMap: $isVisibleOnMap, ')
          ..write('lineStyle: $lineStyle, ')
          ..write('lineColor: $lineColor, ')
          ..write('arrowDirection: $arrowDirection, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDecksTable extends LocalDecks
    with TableInfo<$LocalDecksTable, LocalDeck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _governmentIdMeta =
      const VerificationMeta('governmentId');
  @override
  late final GeneratedColumn<String> governmentId = GeneratedColumn<String>(
      'government_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _externalIdMeta =
      const VerificationMeta('externalId');
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
      'external_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tierOrderMeta =
      const VerificationMeta('tierOrder');
  @override
  late final GeneratedColumn<int> tierOrder = GeneratedColumn<int>(
      'tier_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isPremiumMeta =
      const VerificationMeta('isPremium');
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
      'is_premium', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_premium" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('published'));
  static const VerificationMeta _cardCountMeta =
      const VerificationMeta('cardCount');
  @override
  late final GeneratedColumn<int> cardCount = GeneratedColumn<int>(
      'card_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        nodeId,
        governmentId,
        externalId,
        name,
        description,
        tierOrder,
        isPremium,
        status,
        cardCount,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_decks';
  @override
  VerificationContext validateIntegrity(Insertable<LocalDeck> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    }
    if (data.containsKey('government_id')) {
      context.handle(
          _governmentIdMeta,
          governmentId.isAcceptableOrUnknown(
              data['government_id']!, _governmentIdMeta));
    }
    if (data.containsKey('external_id')) {
      context.handle(
          _externalIdMeta,
          externalId.isAcceptableOrUnknown(
              data['external_id']!, _externalIdMeta));
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('tier_order')) {
      context.handle(_tierOrderMeta,
          tierOrder.isAcceptableOrUnknown(data['tier_order']!, _tierOrderMeta));
    }
    if (data.containsKey('is_premium')) {
      context.handle(_isPremiumMeta,
          isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('card_count')) {
      context.handle(_cardCountMeta,
          cardCount.isAcceptableOrUnknown(data['card_count']!, _cardCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDeck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDeck(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id']),
      governmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}government_id']),
      externalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}external_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      tierOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tier_order'])!,
      isPremium: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_premium'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      cardCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}card_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalDecksTable createAlias(String alias) {
    return $LocalDecksTable(attachedDatabase, alias);
  }
}

class LocalDeck extends DataClass implements Insertable<LocalDeck> {
  final String id;
  final String? nodeId;
  final String? governmentId;
  final String externalId;
  final String name;
  final String? description;
  final int tierOrder;
  final bool isPremium;
  final String status;
  final int cardCount;
  final int updatedAt;
  const LocalDeck(
      {required this.id,
      this.nodeId,
      this.governmentId,
      required this.externalId,
      required this.name,
      this.description,
      required this.tierOrder,
      required this.isPremium,
      required this.status,
      required this.cardCount,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || nodeId != null) {
      map['node_id'] = Variable<String>(nodeId);
    }
    if (!nullToAbsent || governmentId != null) {
      map['government_id'] = Variable<String>(governmentId);
    }
    map['external_id'] = Variable<String>(externalId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['tier_order'] = Variable<int>(tierOrder);
    map['is_premium'] = Variable<bool>(isPremium);
    map['status'] = Variable<String>(status);
    map['card_count'] = Variable<int>(cardCount);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LocalDecksCompanion toCompanion(bool nullToAbsent) {
    return LocalDecksCompanion(
      id: Value(id),
      nodeId:
          nodeId == null && nullToAbsent ? const Value.absent() : Value(nodeId),
      governmentId: governmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(governmentId),
      externalId: Value(externalId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      tierOrder: Value(tierOrder),
      isPremium: Value(isPremium),
      status: Value(status),
      cardCount: Value(cardCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalDeck.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDeck(
      id: serializer.fromJson<String>(json['id']),
      nodeId: serializer.fromJson<String?>(json['nodeId']),
      governmentId: serializer.fromJson<String?>(json['governmentId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      tierOrder: serializer.fromJson<int>(json['tierOrder']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
      status: serializer.fromJson<String>(json['status']),
      cardCount: serializer.fromJson<int>(json['cardCount']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nodeId': serializer.toJson<String?>(nodeId),
      'governmentId': serializer.toJson<String?>(governmentId),
      'externalId': serializer.toJson<String>(externalId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'tierOrder': serializer.toJson<int>(tierOrder),
      'isPremium': serializer.toJson<bool>(isPremium),
      'status': serializer.toJson<String>(status),
      'cardCount': serializer.toJson<int>(cardCount),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LocalDeck copyWith(
          {String? id,
          Value<String?> nodeId = const Value.absent(),
          Value<String?> governmentId = const Value.absent(),
          String? externalId,
          String? name,
          Value<String?> description = const Value.absent(),
          int? tierOrder,
          bool? isPremium,
          String? status,
          int? cardCount,
          int? updatedAt}) =>
      LocalDeck(
        id: id ?? this.id,
        nodeId: nodeId.present ? nodeId.value : this.nodeId,
        governmentId:
            governmentId.present ? governmentId.value : this.governmentId,
        externalId: externalId ?? this.externalId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        tierOrder: tierOrder ?? this.tierOrder,
        isPremium: isPremium ?? this.isPremium,
        status: status ?? this.status,
        cardCount: cardCount ?? this.cardCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalDeck copyWithCompanion(LocalDecksCompanion data) {
    return LocalDeck(
      id: data.id.present ? data.id.value : this.id,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      governmentId: data.governmentId.present
          ? data.governmentId.value
          : this.governmentId,
      externalId:
          data.externalId.present ? data.externalId.value : this.externalId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      tierOrder: data.tierOrder.present ? data.tierOrder.value : this.tierOrder,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
      status: data.status.present ? data.status.value : this.status,
      cardCount: data.cardCount.present ? data.cardCount.value : this.cardCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDeck(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('governmentId: $governmentId, ')
          ..write('externalId: $externalId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('tierOrder: $tierOrder, ')
          ..write('isPremium: $isPremium, ')
          ..write('status: $status, ')
          ..write('cardCount: $cardCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nodeId, governmentId, externalId, name,
      description, tierOrder, isPremium, status, cardCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDeck &&
          other.id == this.id &&
          other.nodeId == this.nodeId &&
          other.governmentId == this.governmentId &&
          other.externalId == this.externalId &&
          other.name == this.name &&
          other.description == this.description &&
          other.tierOrder == this.tierOrder &&
          other.isPremium == this.isPremium &&
          other.status == this.status &&
          other.cardCount == this.cardCount &&
          other.updatedAt == this.updatedAt);
}

class LocalDecksCompanion extends UpdateCompanion<LocalDeck> {
  final Value<String> id;
  final Value<String?> nodeId;
  final Value<String?> governmentId;
  final Value<String> externalId;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> tierOrder;
  final Value<bool> isPremium;
  final Value<String> status;
  final Value<int> cardCount;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LocalDecksCompanion({
    this.id = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.governmentId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.tierOrder = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.status = const Value.absent(),
    this.cardCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDecksCompanion.insert({
    required String id,
    this.nodeId = const Value.absent(),
    this.governmentId = const Value.absent(),
    required String externalId,
    required String name,
    this.description = const Value.absent(),
    this.tierOrder = const Value.absent(),
    this.isPremium = const Value.absent(),
    this.status = const Value.absent(),
    this.cardCount = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        externalId = Value(externalId),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<LocalDeck> custom({
    Expression<String>? id,
    Expression<String>? nodeId,
    Expression<String>? governmentId,
    Expression<String>? externalId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? tierOrder,
    Expression<bool>? isPremium,
    Expression<String>? status,
    Expression<int>? cardCount,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nodeId != null) 'node_id': nodeId,
      if (governmentId != null) 'government_id': governmentId,
      if (externalId != null) 'external_id': externalId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (tierOrder != null) 'tier_order': tierOrder,
      if (isPremium != null) 'is_premium': isPremium,
      if (status != null) 'status': status,
      if (cardCount != null) 'card_count': cardCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDecksCompanion copyWith(
      {Value<String>? id,
      Value<String?>? nodeId,
      Value<String?>? governmentId,
      Value<String>? externalId,
      Value<String>? name,
      Value<String?>? description,
      Value<int>? tierOrder,
      Value<bool>? isPremium,
      Value<String>? status,
      Value<int>? cardCount,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return LocalDecksCompanion(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      governmentId: governmentId ?? this.governmentId,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      description: description ?? this.description,
      tierOrder: tierOrder ?? this.tierOrder,
      isPremium: isPremium ?? this.isPremium,
      status: status ?? this.status,
      cardCount: cardCount ?? this.cardCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (governmentId.present) {
      map['government_id'] = Variable<String>(governmentId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (tierOrder.present) {
      map['tier_order'] = Variable<int>(tierOrder.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (cardCount.present) {
      map['card_count'] = Variable<int>(cardCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDecksCompanion(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('governmentId: $governmentId, ')
          ..write('externalId: $externalId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('tierOrder: $tierOrder, ')
          ..write('isPremium: $isPremium, ')
          ..write('status: $status, ')
          ..write('cardCount: $cardCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCardsTable extends LocalCards
    with TableInfo<$LocalCardsTable, LocalCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
      'deck_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _externalIdMeta =
      const VerificationMeta('externalId');
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
      'external_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _politicianNameMeta =
      const VerificationMeta('politicianName');
  @override
  late final GeneratedColumn<String> politicianName = GeneratedColumn<String>(
      'politician_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lqipBase64Meta =
      const VerificationMeta('lqipBase64');
  @override
  late final GeneratedColumn<String> lqipBase64 = GeneratedColumn<String>(
      'lqip_base64', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partyMeta = const VerificationMeta('party');
  @override
  late final GeneratedColumn<String> party = GeneratedColumn<String>(
      'party', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _jurisdictionMeta =
      const VerificationMeta('jurisdiction');
  @override
  late final GeneratedColumn<String> jurisdiction = GeneratedColumn<String>(
      'jurisdiction', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _oneLinerMeta =
      const VerificationMeta('oneLiner');
  @override
  late final GeneratedColumn<String> oneLiner = GeneratedColumn<String>(
      'one_liner', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cardTypeMeta =
      const VerificationMeta('cardType');
  @override
  late final GeneratedColumn<String> cardType = GeneratedColumn<String>(
      'card_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('face'));
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recallPromptMeta =
      const VerificationMeta('recallPrompt');
  @override
  late final GeneratedColumn<String> recallPrompt = GeneratedColumn<String>(
      'recall_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        deckId,
        externalId,
        politicianName,
        photoUrl,
        lqipBase64,
        title,
        party,
        jurisdiction,
        oneLiner,
        sourceUrl,
        gender,
        cardType,
        body,
        recallPrompt,
        tags,
        isActive,
        sortOrder,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_cards';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCard> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(_deckIdMeta,
          deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta));
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
          _externalIdMeta,
          externalId.isAcceptableOrUnknown(
              data['external_id']!, _externalIdMeta));
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('politician_name')) {
      context.handle(
          _politicianNameMeta,
          politicianName.isAcceptableOrUnknown(
              data['politician_name']!, _politicianNameMeta));
    } else if (isInserting) {
      context.missing(_politicianNameMeta);
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('lqip_base64')) {
      context.handle(
          _lqipBase64Meta,
          lqipBase64.isAcceptableOrUnknown(
              data['lqip_base64']!, _lqipBase64Meta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('party')) {
      context.handle(
          _partyMeta, party.isAcceptableOrUnknown(data['party']!, _partyMeta));
    }
    if (data.containsKey('jurisdiction')) {
      context.handle(
          _jurisdictionMeta,
          jurisdiction.isAcceptableOrUnknown(
              data['jurisdiction']!, _jurisdictionMeta));
    }
    if (data.containsKey('one_liner')) {
      context.handle(_oneLinerMeta,
          oneLiner.isAcceptableOrUnknown(data['one_liner']!, _oneLinerMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    }
    if (data.containsKey('card_type')) {
      context.handle(_cardTypeMeta,
          cardType.isAcceptableOrUnknown(data['card_type']!, _cardTypeMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('recall_prompt')) {
      context.handle(
          _recallPromptMeta,
          recallPrompt.isAcceptableOrUnknown(
              data['recall_prompt']!, _recallPromptMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCard(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      deckId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deck_id'])!,
      externalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}external_id'])!,
      politicianName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}politician_name'])!,
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url']),
      lqipBase64: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lqip_base64']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      party: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}party']),
      jurisdiction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jurisdiction']),
      oneLiner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}one_liner']),
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender']),
      cardType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_type'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      recallPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recall_prompt']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalCardsTable createAlias(String alias) {
    return $LocalCardsTable(attachedDatabase, alias);
  }
}

class LocalCard extends DataClass implements Insertable<LocalCard> {
  final String id;
  final String deckId;
  final String externalId;
  final String politicianName;
  final String? photoUrl;
  final String? lqipBase64;
  final String title;
  final String? party;
  final String? jurisdiction;
  final String? oneLiner;
  final String sourceUrl;
  final String? gender;
  final String cardType;
  final String? body;
  final String? recallPrompt;
  final String tags;
  final bool isActive;
  final int sortOrder;
  final int updatedAt;
  const LocalCard(
      {required this.id,
      required this.deckId,
      required this.externalId,
      required this.politicianName,
      this.photoUrl,
      this.lqipBase64,
      required this.title,
      this.party,
      this.jurisdiction,
      this.oneLiner,
      required this.sourceUrl,
      this.gender,
      required this.cardType,
      this.body,
      this.recallPrompt,
      required this.tags,
      required this.isActive,
      required this.sortOrder,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['external_id'] = Variable<String>(externalId);
    map['politician_name'] = Variable<String>(politicianName);
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || lqipBase64 != null) {
      map['lqip_base64'] = Variable<String>(lqipBase64);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || party != null) {
      map['party'] = Variable<String>(party);
    }
    if (!nullToAbsent || jurisdiction != null) {
      map['jurisdiction'] = Variable<String>(jurisdiction);
    }
    if (!nullToAbsent || oneLiner != null) {
      map['one_liner'] = Variable<String>(oneLiner);
    }
    map['source_url'] = Variable<String>(sourceUrl);
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    map['card_type'] = Variable<String>(cardType);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || recallPrompt != null) {
      map['recall_prompt'] = Variable<String>(recallPrompt);
    }
    map['tags'] = Variable<String>(tags);
    map['is_active'] = Variable<bool>(isActive);
    map['sort_order'] = Variable<int>(sortOrder);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LocalCardsCompanion toCompanion(bool nullToAbsent) {
    return LocalCardsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      externalId: Value(externalId),
      politicianName: Value(politicianName),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      lqipBase64: lqipBase64 == null && nullToAbsent
          ? const Value.absent()
          : Value(lqipBase64),
      title: Value(title),
      party:
          party == null && nullToAbsent ? const Value.absent() : Value(party),
      jurisdiction: jurisdiction == null && nullToAbsent
          ? const Value.absent()
          : Value(jurisdiction),
      oneLiner: oneLiner == null && nullToAbsent
          ? const Value.absent()
          : Value(oneLiner),
      sourceUrl: Value(sourceUrl),
      gender:
          gender == null && nullToAbsent ? const Value.absent() : Value(gender),
      cardType: Value(cardType),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      recallPrompt: recallPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(recallPrompt),
      tags: Value(tags),
      isActive: Value(isActive),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalCard.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCard(
      id: serializer.fromJson<String>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      politicianName: serializer.fromJson<String>(json['politicianName']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      lqipBase64: serializer.fromJson<String?>(json['lqipBase64']),
      title: serializer.fromJson<String>(json['title']),
      party: serializer.fromJson<String?>(json['party']),
      jurisdiction: serializer.fromJson<String?>(json['jurisdiction']),
      oneLiner: serializer.fromJson<String?>(json['oneLiner']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      gender: serializer.fromJson<String?>(json['gender']),
      cardType: serializer.fromJson<String>(json['cardType']),
      body: serializer.fromJson<String?>(json['body']),
      recallPrompt: serializer.fromJson<String?>(json['recallPrompt']),
      tags: serializer.fromJson<String>(json['tags']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deckId': serializer.toJson<String>(deckId),
      'externalId': serializer.toJson<String>(externalId),
      'politicianName': serializer.toJson<String>(politicianName),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'lqipBase64': serializer.toJson<String?>(lqipBase64),
      'title': serializer.toJson<String>(title),
      'party': serializer.toJson<String?>(party),
      'jurisdiction': serializer.toJson<String?>(jurisdiction),
      'oneLiner': serializer.toJson<String?>(oneLiner),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'gender': serializer.toJson<String?>(gender),
      'cardType': serializer.toJson<String>(cardType),
      'body': serializer.toJson<String?>(body),
      'recallPrompt': serializer.toJson<String?>(recallPrompt),
      'tags': serializer.toJson<String>(tags),
      'isActive': serializer.toJson<bool>(isActive),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LocalCard copyWith(
          {String? id,
          String? deckId,
          String? externalId,
          String? politicianName,
          Value<String?> photoUrl = const Value.absent(),
          Value<String?> lqipBase64 = const Value.absent(),
          String? title,
          Value<String?> party = const Value.absent(),
          Value<String?> jurisdiction = const Value.absent(),
          Value<String?> oneLiner = const Value.absent(),
          String? sourceUrl,
          Value<String?> gender = const Value.absent(),
          String? cardType,
          Value<String?> body = const Value.absent(),
          Value<String?> recallPrompt = const Value.absent(),
          String? tags,
          bool? isActive,
          int? sortOrder,
          int? updatedAt}) =>
      LocalCard(
        id: id ?? this.id,
        deckId: deckId ?? this.deckId,
        externalId: externalId ?? this.externalId,
        politicianName: politicianName ?? this.politicianName,
        photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
        lqipBase64: lqipBase64.present ? lqipBase64.value : this.lqipBase64,
        title: title ?? this.title,
        party: party.present ? party.value : this.party,
        jurisdiction:
            jurisdiction.present ? jurisdiction.value : this.jurisdiction,
        oneLiner: oneLiner.present ? oneLiner.value : this.oneLiner,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        gender: gender.present ? gender.value : this.gender,
        cardType: cardType ?? this.cardType,
        body: body.present ? body.value : this.body,
        recallPrompt:
            recallPrompt.present ? recallPrompt.value : this.recallPrompt,
        tags: tags ?? this.tags,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalCard copyWithCompanion(LocalCardsCompanion data) {
    return LocalCard(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      externalId:
          data.externalId.present ? data.externalId.value : this.externalId,
      politicianName: data.politicianName.present
          ? data.politicianName.value
          : this.politicianName,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      lqipBase64:
          data.lqipBase64.present ? data.lqipBase64.value : this.lqipBase64,
      title: data.title.present ? data.title.value : this.title,
      party: data.party.present ? data.party.value : this.party,
      jurisdiction: data.jurisdiction.present
          ? data.jurisdiction.value
          : this.jurisdiction,
      oneLiner: data.oneLiner.present ? data.oneLiner.value : this.oneLiner,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      gender: data.gender.present ? data.gender.value : this.gender,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      body: data.body.present ? data.body.value : this.body,
      recallPrompt: data.recallPrompt.present
          ? data.recallPrompt.value
          : this.recallPrompt,
      tags: data.tags.present ? data.tags.value : this.tags,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCard(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('externalId: $externalId, ')
          ..write('politicianName: $politicianName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('lqipBase64: $lqipBase64, ')
          ..write('title: $title, ')
          ..write('party: $party, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('oneLiner: $oneLiner, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('gender: $gender, ')
          ..write('cardType: $cardType, ')
          ..write('body: $body, ')
          ..write('recallPrompt: $recallPrompt, ')
          ..write('tags: $tags, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      deckId,
      externalId,
      politicianName,
      photoUrl,
      lqipBase64,
      title,
      party,
      jurisdiction,
      oneLiner,
      sourceUrl,
      gender,
      cardType,
      body,
      recallPrompt,
      tags,
      isActive,
      sortOrder,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCard &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.externalId == this.externalId &&
          other.politicianName == this.politicianName &&
          other.photoUrl == this.photoUrl &&
          other.lqipBase64 == this.lqipBase64 &&
          other.title == this.title &&
          other.party == this.party &&
          other.jurisdiction == this.jurisdiction &&
          other.oneLiner == this.oneLiner &&
          other.sourceUrl == this.sourceUrl &&
          other.gender == this.gender &&
          other.cardType == this.cardType &&
          other.body == this.body &&
          other.recallPrompt == this.recallPrompt &&
          other.tags == this.tags &&
          other.isActive == this.isActive &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt);
}

class LocalCardsCompanion extends UpdateCompanion<LocalCard> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> externalId;
  final Value<String> politicianName;
  final Value<String?> photoUrl;
  final Value<String?> lqipBase64;
  final Value<String> title;
  final Value<String?> party;
  final Value<String?> jurisdiction;
  final Value<String?> oneLiner;
  final Value<String> sourceUrl;
  final Value<String?> gender;
  final Value<String> cardType;
  final Value<String?> body;
  final Value<String?> recallPrompt;
  final Value<String> tags;
  final Value<bool> isActive;
  final Value<int> sortOrder;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LocalCardsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.politicianName = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.lqipBase64 = const Value.absent(),
    this.title = const Value.absent(),
    this.party = const Value.absent(),
    this.jurisdiction = const Value.absent(),
    this.oneLiner = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.gender = const Value.absent(),
    this.cardType = const Value.absent(),
    this.body = const Value.absent(),
    this.recallPrompt = const Value.absent(),
    this.tags = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCardsCompanion.insert({
    required String id,
    required String deckId,
    required String externalId,
    required String politicianName,
    this.photoUrl = const Value.absent(),
    this.lqipBase64 = const Value.absent(),
    required String title,
    this.party = const Value.absent(),
    this.jurisdiction = const Value.absent(),
    this.oneLiner = const Value.absent(),
    required String sourceUrl,
    this.gender = const Value.absent(),
    this.cardType = const Value.absent(),
    this.body = const Value.absent(),
    this.recallPrompt = const Value.absent(),
    this.tags = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        deckId = Value(deckId),
        externalId = Value(externalId),
        politicianName = Value(politicianName),
        title = Value(title),
        sourceUrl = Value(sourceUrl),
        updatedAt = Value(updatedAt);
  static Insertable<LocalCard> custom({
    Expression<String>? id,
    Expression<String>? deckId,
    Expression<String>? externalId,
    Expression<String>? politicianName,
    Expression<String>? photoUrl,
    Expression<String>? lqipBase64,
    Expression<String>? title,
    Expression<String>? party,
    Expression<String>? jurisdiction,
    Expression<String>? oneLiner,
    Expression<String>? sourceUrl,
    Expression<String>? gender,
    Expression<String>? cardType,
    Expression<String>? body,
    Expression<String>? recallPrompt,
    Expression<String>? tags,
    Expression<bool>? isActive,
    Expression<int>? sortOrder,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (externalId != null) 'external_id': externalId,
      if (politicianName != null) 'politician_name': politicianName,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (lqipBase64 != null) 'lqip_base64': lqipBase64,
      if (title != null) 'title': title,
      if (party != null) 'party': party,
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
      if (oneLiner != null) 'one_liner': oneLiner,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (gender != null) 'gender': gender,
      if (cardType != null) 'card_type': cardType,
      if (body != null) 'body': body,
      if (recallPrompt != null) 'recall_prompt': recallPrompt,
      if (tags != null) 'tags': tags,
      if (isActive != null) 'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCardsCompanion copyWith(
      {Value<String>? id,
      Value<String>? deckId,
      Value<String>? externalId,
      Value<String>? politicianName,
      Value<String?>? photoUrl,
      Value<String?>? lqipBase64,
      Value<String>? title,
      Value<String?>? party,
      Value<String?>? jurisdiction,
      Value<String?>? oneLiner,
      Value<String>? sourceUrl,
      Value<String?>? gender,
      Value<String>? cardType,
      Value<String?>? body,
      Value<String?>? recallPrompt,
      Value<String>? tags,
      Value<bool>? isActive,
      Value<int>? sortOrder,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return LocalCardsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      externalId: externalId ?? this.externalId,
      politicianName: politicianName ?? this.politicianName,
      photoUrl: photoUrl ?? this.photoUrl,
      lqipBase64: lqipBase64 ?? this.lqipBase64,
      title: title ?? this.title,
      party: party ?? this.party,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      oneLiner: oneLiner ?? this.oneLiner,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      gender: gender ?? this.gender,
      cardType: cardType ?? this.cardType,
      body: body ?? this.body,
      recallPrompt: recallPrompt ?? this.recallPrompt,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (politicianName.present) {
      map['politician_name'] = Variable<String>(politicianName.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (lqipBase64.present) {
      map['lqip_base64'] = Variable<String>(lqipBase64.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (party.present) {
      map['party'] = Variable<String>(party.value);
    }
    if (jurisdiction.present) {
      map['jurisdiction'] = Variable<String>(jurisdiction.value);
    }
    if (oneLiner.present) {
      map['one_liner'] = Variable<String>(oneLiner.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(cardType.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (recallPrompt.present) {
      map['recall_prompt'] = Variable<String>(recallPrompt.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCardsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('externalId: $externalId, ')
          ..write('politicianName: $politicianName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('lqipBase64: $lqipBase64, ')
          ..write('title: $title, ')
          ..write('party: $party, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('oneLiner: $oneLiner, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('gender: $gender, ')
          ..write('cardType: $cardType, ')
          ..write('body: $body, ')
          ..write('recallPrompt: $recallPrompt, ')
          ..write('tags: $tags, ')
          ..write('isActive: $isActive, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardMemoryStatesTable extends CardMemoryStates
    with TableInfo<$CardMemoryStatesTable, CardMemoryState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardMemoryStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
      'card_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _stabilityMeta =
      const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
      'stability', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _retrievabilityMeta =
      const VerificationMeta('retrievability');
  @override
  late final GeneratedColumn<double> retrievability = GeneratedColumn<double>(
      'retrievability', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastReviewedAtMeta =
      const VerificationMeta('lastReviewedAt');
  @override
  late final GeneratedColumn<int> lastReviewedAt = GeneratedColumn<int>(
      'last_reviewed_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextReviewAtMeta =
      const VerificationMeta('nextReviewAt');
  @override
  late final GeneratedColumn<int> nextReviewAt = GeneratedColumn<int>(
      'next_review_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _intervalDaysMeta =
      const VerificationMeta('intervalDays');
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
      'interval_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
      'lapses', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _reviewCountMeta =
      const VerificationMeta('reviewCount');
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
      'review_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
      'is_new', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_new" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _practiceCountSinceReviewMeta =
      const VerificationMeta('practiceCountSinceReview');
  @override
  late final GeneratedColumn<int> practiceCountSinceReview =
      GeneratedColumn<int>('practice_count_since_review', aliasedName, false,
          type: DriftSqlType.int,
          requiredDuringInsert: false,
          defaultValue: const Constant(0));
  static const VerificationMeta _lastGradeMeta =
      const VerificationMeta('lastGrade');
  @override
  late final GeneratedColumn<int> lastGrade = GeneratedColumn<int>(
      'last_grade', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        cardId,
        userId,
        difficulty,
        stability,
        retrievability,
        lastReviewedAt,
        nextReviewAt,
        intervalDays,
        lapses,
        reviewCount,
        isNew,
        practiceCountSinceReview,
        lastGrade
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_memory_states';
  @override
  VerificationContext validateIntegrity(Insertable<CardMemoryState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta,
          cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('stability')) {
      context.handle(_stabilityMeta,
          stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta));
    }
    if (data.containsKey('retrievability')) {
      context.handle(
          _retrievabilityMeta,
          retrievability.isAcceptableOrUnknown(
              data['retrievability']!, _retrievabilityMeta));
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
          _lastReviewedAtMeta,
          lastReviewedAt.isAcceptableOrUnknown(
              data['last_reviewed_at']!, _lastReviewedAtMeta));
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
          _nextReviewAtMeta,
          nextReviewAt.isAcceptableOrUnknown(
              data['next_review_at']!, _nextReviewAtMeta));
    }
    if (data.containsKey('interval_days')) {
      context.handle(
          _intervalDaysMeta,
          intervalDays.isAcceptableOrUnknown(
              data['interval_days']!, _intervalDaysMeta));
    }
    if (data.containsKey('lapses')) {
      context.handle(_lapsesMeta,
          lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta));
    }
    if (data.containsKey('review_count')) {
      context.handle(
          _reviewCountMeta,
          reviewCount.isAcceptableOrUnknown(
              data['review_count']!, _reviewCountMeta));
    }
    if (data.containsKey('is_new')) {
      context.handle(
          _isNewMeta, isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta));
    }
    if (data.containsKey('practice_count_since_review')) {
      context.handle(
          _practiceCountSinceReviewMeta,
          practiceCountSinceReview.isAcceptableOrUnknown(
              data['practice_count_since_review']!,
              _practiceCountSinceReviewMeta));
    }
    if (data.containsKey('last_grade')) {
      context.handle(_lastGradeMeta,
          lastGrade.isAcceptableOrUnknown(data['last_grade']!, _lastGradeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  CardMemoryState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardMemoryState(
      cardId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}difficulty'])!,
      stability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stability'])!,
      retrievability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}retrievability'])!,
      lastReviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_reviewed_at'])!,
      nextReviewAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_review_at'])!,
      intervalDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval_days'])!,
      lapses: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lapses'])!,
      reviewCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}review_count'])!,
      isNew: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_new'])!,
      practiceCountSinceReview: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}practice_count_since_review'])!,
      lastGrade: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_grade'])!,
    );
  }

  @override
  $CardMemoryStatesTable createAlias(String alias) {
    return $CardMemoryStatesTable(attachedDatabase, alias);
  }
}

class CardMemoryState extends DataClass implements Insertable<CardMemoryState> {
  final String cardId;
  final String userId;
  final double difficulty;
  final double stability;
  final double retrievability;
  final int lastReviewedAt;
  final int nextReviewAt;
  final int intervalDays;
  final int lapses;
  final int reviewCount;
  final bool isNew;
  final int practiceCountSinceReview;
  final int lastGrade;
  const CardMemoryState(
      {required this.cardId,
      required this.userId,
      required this.difficulty,
      required this.stability,
      required this.retrievability,
      required this.lastReviewedAt,
      required this.nextReviewAt,
      required this.intervalDays,
      required this.lapses,
      required this.reviewCount,
      required this.isNew,
      required this.practiceCountSinceReview,
      required this.lastGrade});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<String>(cardId);
    map['user_id'] = Variable<String>(userId);
    map['difficulty'] = Variable<double>(difficulty);
    map['stability'] = Variable<double>(stability);
    map['retrievability'] = Variable<double>(retrievability);
    map['last_reviewed_at'] = Variable<int>(lastReviewedAt);
    map['next_review_at'] = Variable<int>(nextReviewAt);
    map['interval_days'] = Variable<int>(intervalDays);
    map['lapses'] = Variable<int>(lapses);
    map['review_count'] = Variable<int>(reviewCount);
    map['is_new'] = Variable<bool>(isNew);
    map['practice_count_since_review'] =
        Variable<int>(practiceCountSinceReview);
    map['last_grade'] = Variable<int>(lastGrade);
    return map;
  }

  CardMemoryStatesCompanion toCompanion(bool nullToAbsent) {
    return CardMemoryStatesCompanion(
      cardId: Value(cardId),
      userId: Value(userId),
      difficulty: Value(difficulty),
      stability: Value(stability),
      retrievability: Value(retrievability),
      lastReviewedAt: Value(lastReviewedAt),
      nextReviewAt: Value(nextReviewAt),
      intervalDays: Value(intervalDays),
      lapses: Value(lapses),
      reviewCount: Value(reviewCount),
      isNew: Value(isNew),
      practiceCountSinceReview: Value(practiceCountSinceReview),
      lastGrade: Value(lastGrade),
    );
  }

  factory CardMemoryState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardMemoryState(
      cardId: serializer.fromJson<String>(json['cardId']),
      userId: serializer.fromJson<String>(json['userId']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      stability: serializer.fromJson<double>(json['stability']),
      retrievability: serializer.fromJson<double>(json['retrievability']),
      lastReviewedAt: serializer.fromJson<int>(json['lastReviewedAt']),
      nextReviewAt: serializer.fromJson<int>(json['nextReviewAt']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      lapses: serializer.fromJson<int>(json['lapses']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      practiceCountSinceReview:
          serializer.fromJson<int>(json['practiceCountSinceReview']),
      lastGrade: serializer.fromJson<int>(json['lastGrade']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<String>(cardId),
      'userId': serializer.toJson<String>(userId),
      'difficulty': serializer.toJson<double>(difficulty),
      'stability': serializer.toJson<double>(stability),
      'retrievability': serializer.toJson<double>(retrievability),
      'lastReviewedAt': serializer.toJson<int>(lastReviewedAt),
      'nextReviewAt': serializer.toJson<int>(nextReviewAt),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'lapses': serializer.toJson<int>(lapses),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'isNew': serializer.toJson<bool>(isNew),
      'practiceCountSinceReview':
          serializer.toJson<int>(practiceCountSinceReview),
      'lastGrade': serializer.toJson<int>(lastGrade),
    };
  }

  CardMemoryState copyWith(
          {String? cardId,
          String? userId,
          double? difficulty,
          double? stability,
          double? retrievability,
          int? lastReviewedAt,
          int? nextReviewAt,
          int? intervalDays,
          int? lapses,
          int? reviewCount,
          bool? isNew,
          int? practiceCountSinceReview,
          int? lastGrade}) =>
      CardMemoryState(
        cardId: cardId ?? this.cardId,
        userId: userId ?? this.userId,
        difficulty: difficulty ?? this.difficulty,
        stability: stability ?? this.stability,
        retrievability: retrievability ?? this.retrievability,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        intervalDays: intervalDays ?? this.intervalDays,
        lapses: lapses ?? this.lapses,
        reviewCount: reviewCount ?? this.reviewCount,
        isNew: isNew ?? this.isNew,
        practiceCountSinceReview:
            practiceCountSinceReview ?? this.practiceCountSinceReview,
        lastGrade: lastGrade ?? this.lastGrade,
      );
  CardMemoryState copyWithCompanion(CardMemoryStatesCompanion data) {
    return CardMemoryState(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      userId: data.userId.present ? data.userId.value : this.userId,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      stability: data.stability.present ? data.stability.value : this.stability,
      retrievability: data.retrievability.present
          ? data.retrievability.value
          : this.retrievability,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      reviewCount:
          data.reviewCount.present ? data.reviewCount.value : this.reviewCount,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      practiceCountSinceReview: data.practiceCountSinceReview.present
          ? data.practiceCountSinceReview.value
          : this.practiceCountSinceReview,
      lastGrade: data.lastGrade.present ? data.lastGrade.value : this.lastGrade,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardMemoryState(')
          ..write('cardId: $cardId, ')
          ..write('userId: $userId, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('retrievability: $retrievability, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('lapses: $lapses, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('isNew: $isNew, ')
          ..write('practiceCountSinceReview: $practiceCountSinceReview, ')
          ..write('lastGrade: $lastGrade')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      cardId,
      userId,
      difficulty,
      stability,
      retrievability,
      lastReviewedAt,
      nextReviewAt,
      intervalDays,
      lapses,
      reviewCount,
      isNew,
      practiceCountSinceReview,
      lastGrade);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardMemoryState &&
          other.cardId == this.cardId &&
          other.userId == this.userId &&
          other.difficulty == this.difficulty &&
          other.stability == this.stability &&
          other.retrievability == this.retrievability &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.nextReviewAt == this.nextReviewAt &&
          other.intervalDays == this.intervalDays &&
          other.lapses == this.lapses &&
          other.reviewCount == this.reviewCount &&
          other.isNew == this.isNew &&
          other.practiceCountSinceReview == this.practiceCountSinceReview &&
          other.lastGrade == this.lastGrade);
}

class CardMemoryStatesCompanion extends UpdateCompanion<CardMemoryState> {
  final Value<String> cardId;
  final Value<String> userId;
  final Value<double> difficulty;
  final Value<double> stability;
  final Value<double> retrievability;
  final Value<int> lastReviewedAt;
  final Value<int> nextReviewAt;
  final Value<int> intervalDays;
  final Value<int> lapses;
  final Value<int> reviewCount;
  final Value<bool> isNew;
  final Value<int> practiceCountSinceReview;
  final Value<int> lastGrade;
  final Value<int> rowid;
  const CardMemoryStatesCompanion({
    this.cardId = const Value.absent(),
    this.userId = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stability = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.lapses = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.isNew = const Value.absent(),
    this.practiceCountSinceReview = const Value.absent(),
    this.lastGrade = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardMemoryStatesCompanion.insert({
    required String cardId,
    this.userId = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stability = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.lapses = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.isNew = const Value.absent(),
    this.practiceCountSinceReview = const Value.absent(),
    this.lastGrade = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId);
  static Insertable<CardMemoryState> custom({
    Expression<String>? cardId,
    Expression<String>? userId,
    Expression<double>? difficulty,
    Expression<double>? stability,
    Expression<double>? retrievability,
    Expression<int>? lastReviewedAt,
    Expression<int>? nextReviewAt,
    Expression<int>? intervalDays,
    Expression<int>? lapses,
    Expression<int>? reviewCount,
    Expression<bool>? isNew,
    Expression<int>? practiceCountSinceReview,
    Expression<int>? lastGrade,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (userId != null) 'user_id': userId,
      if (difficulty != null) 'difficulty': difficulty,
      if (stability != null) 'stability': stability,
      if (retrievability != null) 'retrievability': retrievability,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (lapses != null) 'lapses': lapses,
      if (reviewCount != null) 'review_count': reviewCount,
      if (isNew != null) 'is_new': isNew,
      if (practiceCountSinceReview != null)
        'practice_count_since_review': practiceCountSinceReview,
      if (lastGrade != null) 'last_grade': lastGrade,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardMemoryStatesCompanion copyWith(
      {Value<String>? cardId,
      Value<String>? userId,
      Value<double>? difficulty,
      Value<double>? stability,
      Value<double>? retrievability,
      Value<int>? lastReviewedAt,
      Value<int>? nextReviewAt,
      Value<int>? intervalDays,
      Value<int>? lapses,
      Value<int>? reviewCount,
      Value<bool>? isNew,
      Value<int>? practiceCountSinceReview,
      Value<int>? lastGrade,
      Value<int>? rowid}) {
    return CardMemoryStatesCompanion(
      cardId: cardId ?? this.cardId,
      userId: userId ?? this.userId,
      difficulty: difficulty ?? this.difficulty,
      stability: stability ?? this.stability,
      retrievability: retrievability ?? this.retrievability,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      intervalDays: intervalDays ?? this.intervalDays,
      lapses: lapses ?? this.lapses,
      reviewCount: reviewCount ?? this.reviewCount,
      isNew: isNew ?? this.isNew,
      practiceCountSinceReview:
          practiceCountSinceReview ?? this.practiceCountSinceReview,
      lastGrade: lastGrade ?? this.lastGrade,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (retrievability.present) {
      map['retrievability'] = Variable<double>(retrievability.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<int>(lastReviewedAt.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<int>(nextReviewAt.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (practiceCountSinceReview.present) {
      map['practice_count_since_review'] =
          Variable<int>(practiceCountSinceReview.value);
    }
    if (lastGrade.present) {
      map['last_grade'] = Variable<int>(lastGrade.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardMemoryStatesCompanion(')
          ..write('cardId: $cardId, ')
          ..write('userId: $userId, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('retrievability: $retrievability, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('lapses: $lapses, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('isNew: $isNew, ')
          ..write('practiceCountSinceReview: $practiceCountSinceReview, ')
          ..write('lastGrade: $lastGrade, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs
    with TableInfo<$ReviewLogsTable, ReviewLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
      'card_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reviewedAtMeta =
      const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<int> reviewedAt = GeneratedColumn<int>(
      'reviewed_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
      'grade', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stabilityMeta =
      const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
      'stability', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _retrievabilityMeta =
      const VerificationMeta('retrievability');
  @override
  late final GeneratedColumn<double> retrievability = GeneratedColumn<double>(
      'retrievability', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _intervalDaysMeta =
      const VerificationMeta('intervalDays');
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
      'interval_days', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        cardId,
        reviewedAt,
        grade,
        stability,
        difficulty,
        retrievability,
        intervalDays,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(Insertable<ReviewLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta,
          cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
          _reviewedAtMeta,
          reviewedAt.isAcceptableOrUnknown(
              data['reviewed_at']!, _reviewedAtMeta));
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
          _gradeMeta, grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta));
    } else if (isInserting) {
      context.missing(_gradeMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(_stabilityMeta,
          stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta));
    } else if (isInserting) {
      context.missing(_stabilityMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('retrievability')) {
      context.handle(
          _retrievabilityMeta,
          retrievability.isAcceptableOrUnknown(
              data['retrievability']!, _retrievabilityMeta));
    } else if (isInserting) {
      context.missing(_retrievabilityMeta);
    }
    if (data.containsKey('interval_days')) {
      context.handle(
          _intervalDaysMeta,
          intervalDays.isAcceptableOrUnknown(
              data['interval_days']!, _intervalDaysMeta));
    } else if (isInserting) {
      context.missing(_intervalDaysMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      cardId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_id'])!,
      reviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reviewed_at'])!,
      grade: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}grade'])!,
      stability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stability'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}difficulty'])!,
      retrievability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}retrievability'])!,
      intervalDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval_days'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }
}

class ReviewLog extends DataClass implements Insertable<ReviewLog> {
  final int id;
  final String userId;
  final String cardId;
  final int reviewedAt;
  final int grade;
  final double stability;
  final double difficulty;
  final double retrievability;
  final int intervalDays;
  final bool synced;
  const ReviewLog(
      {required this.id,
      required this.userId,
      required this.cardId,
      required this.reviewedAt,
      required this.grade,
      required this.stability,
      required this.difficulty,
      required this.retrievability,
      required this.intervalDays,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['card_id'] = Variable<String>(cardId);
    map['reviewed_at'] = Variable<int>(reviewedAt);
    map['grade'] = Variable<int>(grade);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['retrievability'] = Variable<double>(retrievability);
    map['interval_days'] = Variable<int>(intervalDays);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      userId: Value(userId),
      cardId: Value(cardId),
      reviewedAt: Value(reviewedAt),
      grade: Value(grade),
      stability: Value(stability),
      difficulty: Value(difficulty),
      retrievability: Value(retrievability),
      intervalDays: Value(intervalDays),
      synced: Value(synced),
    );
  }

  factory ReviewLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLog(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      cardId: serializer.fromJson<String>(json['cardId']),
      reviewedAt: serializer.fromJson<int>(json['reviewedAt']),
      grade: serializer.fromJson<int>(json['grade']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      retrievability: serializer.fromJson<double>(json['retrievability']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'cardId': serializer.toJson<String>(cardId),
      'reviewedAt': serializer.toJson<int>(reviewedAt),
      'grade': serializer.toJson<int>(grade),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'retrievability': serializer.toJson<double>(retrievability),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  ReviewLog copyWith(
          {int? id,
          String? userId,
          String? cardId,
          int? reviewedAt,
          int? grade,
          double? stability,
          double? difficulty,
          double? retrievability,
          int? intervalDays,
          bool? synced}) =>
      ReviewLog(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        cardId: cardId ?? this.cardId,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        grade: grade ?? this.grade,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        retrievability: retrievability ?? this.retrievability,
        intervalDays: intervalDays ?? this.intervalDays,
        synced: synced ?? this.synced,
      );
  ReviewLog copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLog(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
      grade: data.grade.present ? data.grade.value : this.grade,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      retrievability: data.retrievability.present
          ? data.retrievability.value
          : this.retrievability,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLog(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('grade: $grade, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, cardId, reviewedAt, grade,
      stability, difficulty, retrievability, intervalDays, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLog &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.cardId == this.cardId &&
          other.reviewedAt == this.reviewedAt &&
          other.grade == this.grade &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.retrievability == this.retrievability &&
          other.intervalDays == this.intervalDays &&
          other.synced == this.synced);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLog> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> cardId;
  final Value<int> reviewedAt;
  final Value<int> grade;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<double> retrievability;
  final Value<int> intervalDays;
  final Value<bool> synced;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.cardId = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.grade = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.synced = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    required String cardId,
    required int reviewedAt,
    required int grade,
    required double stability,
    required double difficulty,
    required double retrievability,
    required int intervalDays,
    this.synced = const Value.absent(),
  })  : cardId = Value(cardId),
        reviewedAt = Value(reviewedAt),
        grade = Value(grade),
        stability = Value(stability),
        difficulty = Value(difficulty),
        retrievability = Value(retrievability),
        intervalDays = Value(intervalDays);
  static Insertable<ReviewLog> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? cardId,
    Expression<int>? reviewedAt,
    Expression<int>? grade,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<double>? retrievability,
    Expression<int>? intervalDays,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (cardId != null) 'card_id': cardId,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (grade != null) 'grade': grade,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (retrievability != null) 'retrievability': retrievability,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (synced != null) 'synced': synced,
    });
  }

  ReviewLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? cardId,
      Value<int>? reviewedAt,
      Value<int>? grade,
      Value<double>? stability,
      Value<double>? difficulty,
      Value<double>? retrievability,
      Value<int>? intervalDays,
      Value<bool>? synced}) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cardId: cardId ?? this.cardId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      grade: grade ?? this.grade,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      intervalDays: intervalDays ?? this.intervalDays,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<int>(reviewedAt.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (retrievability.present) {
      map['retrievability'] = Variable<double>(retrievability.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('cardId: $cardId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('grade: $grade, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $UserNodeProgressTable extends UserNodeProgress
    with TableInfo<$UserNodeProgressTable, UserNodeProgressEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserNodeProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _governmentIdMeta =
      const VerificationMeta('governmentId');
  @override
  late final GeneratedColumn<String> governmentId = GeneratedColumn<String>(
      'government_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('locked'));
  static const VerificationMeta _unlockedAtMeta =
      const VerificationMeta('unlockedAt');
  @override
  late final GeneratedColumn<int> unlockedAt = GeneratedColumn<int>(
      'unlocked_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [nodeId, userId, governmentId, status, unlockedAt, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_node_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<UserNodeProgressEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('government_id')) {
      context.handle(
          _governmentIdMeta,
          governmentId.isAcceptableOrUnknown(
              data['government_id']!, _governmentIdMeta));
    } else if (isInserting) {
      context.missing(_governmentIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
          _unlockedAtMeta,
          unlockedAt.isAcceptableOrUnknown(
              data['unlocked_at']!, _unlockedAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nodeId};
  @override
  UserNodeProgressEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserNodeProgressEntry(
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      governmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}government_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      unlockedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unlocked_at']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $UserNodeProgressTable createAlias(String alias) {
    return $UserNodeProgressTable(attachedDatabase, alias);
  }
}

class UserNodeProgressEntry extends DataClass
    implements Insertable<UserNodeProgressEntry> {
  final String nodeId;
  final String userId;
  final String governmentId;
  final String status;
  final int? unlockedAt;
  final int? completedAt;
  const UserNodeProgressEntry(
      {required this.nodeId,
      required this.userId,
      required this.governmentId,
      required this.status,
      this.unlockedAt,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['node_id'] = Variable<String>(nodeId);
    map['user_id'] = Variable<String>(userId);
    map['government_id'] = Variable<String>(governmentId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || unlockedAt != null) {
      map['unlocked_at'] = Variable<int>(unlockedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  UserNodeProgressCompanion toCompanion(bool nullToAbsent) {
    return UserNodeProgressCompanion(
      nodeId: Value(nodeId),
      userId: Value(userId),
      governmentId: Value(governmentId),
      status: Value(status),
      unlockedAt: unlockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory UserNodeProgressEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserNodeProgressEntry(
      nodeId: serializer.fromJson<String>(json['nodeId']),
      userId: serializer.fromJson<String>(json['userId']),
      governmentId: serializer.fromJson<String>(json['governmentId']),
      status: serializer.fromJson<String>(json['status']),
      unlockedAt: serializer.fromJson<int?>(json['unlockedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nodeId': serializer.toJson<String>(nodeId),
      'userId': serializer.toJson<String>(userId),
      'governmentId': serializer.toJson<String>(governmentId),
      'status': serializer.toJson<String>(status),
      'unlockedAt': serializer.toJson<int?>(unlockedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  UserNodeProgressEntry copyWith(
          {String? nodeId,
          String? userId,
          String? governmentId,
          String? status,
          Value<int?> unlockedAt = const Value.absent(),
          Value<int?> completedAt = const Value.absent()}) =>
      UserNodeProgressEntry(
        nodeId: nodeId ?? this.nodeId,
        userId: userId ?? this.userId,
        governmentId: governmentId ?? this.governmentId,
        status: status ?? this.status,
        unlockedAt: unlockedAt.present ? unlockedAt.value : this.unlockedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  UserNodeProgressEntry copyWithCompanion(UserNodeProgressCompanion data) {
    return UserNodeProgressEntry(
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      userId: data.userId.present ? data.userId.value : this.userId,
      governmentId: data.governmentId.present
          ? data.governmentId.value
          : this.governmentId,
      status: data.status.present ? data.status.value : this.status,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserNodeProgressEntry(')
          ..write('nodeId: $nodeId, ')
          ..write('userId: $userId, ')
          ..write('governmentId: $governmentId, ')
          ..write('status: $status, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      nodeId, userId, governmentId, status, unlockedAt, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserNodeProgressEntry &&
          other.nodeId == this.nodeId &&
          other.userId == this.userId &&
          other.governmentId == this.governmentId &&
          other.status == this.status &&
          other.unlockedAt == this.unlockedAt &&
          other.completedAt == this.completedAt);
}

class UserNodeProgressCompanion extends UpdateCompanion<UserNodeProgressEntry> {
  final Value<String> nodeId;
  final Value<String> userId;
  final Value<String> governmentId;
  final Value<String> status;
  final Value<int?> unlockedAt;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const UserNodeProgressCompanion({
    this.nodeId = const Value.absent(),
    this.userId = const Value.absent(),
    this.governmentId = const Value.absent(),
    this.status = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserNodeProgressCompanion.insert({
    required String nodeId,
    this.userId = const Value.absent(),
    required String governmentId,
    this.status = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : nodeId = Value(nodeId),
        governmentId = Value(governmentId);
  static Insertable<UserNodeProgressEntry> custom({
    Expression<String>? nodeId,
    Expression<String>? userId,
    Expression<String>? governmentId,
    Expression<String>? status,
    Expression<int>? unlockedAt,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nodeId != null) 'node_id': nodeId,
      if (userId != null) 'user_id': userId,
      if (governmentId != null) 'government_id': governmentId,
      if (status != null) 'status': status,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserNodeProgressCompanion copyWith(
      {Value<String>? nodeId,
      Value<String>? userId,
      Value<String>? governmentId,
      Value<String>? status,
      Value<int?>? unlockedAt,
      Value<int?>? completedAt,
      Value<int>? rowid}) {
    return UserNodeProgressCompanion(
      nodeId: nodeId ?? this.nodeId,
      userId: userId ?? this.userId,
      governmentId: governmentId ?? this.governmentId,
      status: status ?? this.status,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (governmentId.present) {
      map['government_id'] = Variable<String>(governmentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<int>(unlockedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserNodeProgressCompanion(')
          ..write('nodeId: $nodeId, ')
          ..write('userId: $userId, ')
          ..write('governmentId: $governmentId, ')
          ..write('status: $status, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, userId, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaData extends DataClass implements Insertable<AppMetaData> {
  final String key;
  final String userId;
  final String value;
  const AppMetaData(
      {required this.key, required this.userId, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['user_id'] = Variable<String>(userId);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(
      key: Value(key),
      userId: Value(userId),
      value: Value(value),
    );
  }

  factory AppMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaData(
      key: serializer.fromJson<String>(json['key']),
      userId: serializer.fromJson<String>(json['userId']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'userId': serializer.toJson<String>(userId),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaData copyWith({String? key, String? userId, String? value}) =>
      AppMetaData(
        key: key ?? this.key,
        userId: userId ?? this.userId,
        value: value ?? this.value,
      );
  AppMetaData copyWithCompanion(AppMetaCompanion data) {
    return AppMetaData(
      key: data.key.present ? data.key.value : this.key,
      userId: data.userId.present ? data.userId.value : this.userId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaData(')
          ..write('key: $key, ')
          ..write('userId: $userId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, userId, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaData &&
          other.key == this.key &&
          other.userId == this.userId &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaData> {
  final Value<String> key;
  final Value<String> userId;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.userId = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    this.userId = const Value.absent(),
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppMetaData> custom({
    Expression<String>? key,
    Expression<String>? userId,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (userId != null) 'user_id': userId,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith(
      {Value<String>? key,
      Value<String>? userId,
      Value<String>? value,
      Value<int>? rowid}) {
    return AppMetaCompanion(
      key: key ?? this.key,
      userId: userId ?? this.userId,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('userId: $userId, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterProgressTable extends ChapterProgress
    with TableInfo<$ChapterProgressTable, ChapterProgressEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _seasonIdMeta =
      const VerificationMeta('seasonId');
  @override
  late final GeneratedColumn<String> seasonId = GeneratedColumn<String>(
      'season_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
      'chapter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dayInChapterMeta =
      const VerificationMeta('dayInChapter');
  @override
  late final GeneratedColumn<int> dayInChapter = GeneratedColumn<int>(
      'day_in_chapter', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _roundsCompletedMeta =
      const VerificationMeta('roundsCompleted');
  @override
  late final GeneratedColumn<int> roundsCompleted = GeneratedColumn<int>(
      'rounds_completed', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        seasonId,
        chapterId,
        dayInChapter,
        roundsCompleted,
        startedAt,
        completedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<ChapterProgressEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('season_id')) {
      context.handle(_seasonIdMeta,
          seasonId.isAcceptableOrUnknown(data['season_id']!, _seasonIdMeta));
    } else if (isInserting) {
      context.missing(_seasonIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('day_in_chapter')) {
      context.handle(
          _dayInChapterMeta,
          dayInChapter.isAcceptableOrUnknown(
              data['day_in_chapter']!, _dayInChapterMeta));
    }
    if (data.containsKey('rounds_completed')) {
      context.handle(
          _roundsCompletedMeta,
          roundsCompleted.isAcceptableOrUnknown(
              data['rounds_completed']!, _roundsCompletedMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, seasonId, chapterId};
  @override
  ChapterProgressEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterProgressEntry(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      seasonId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}season_id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_id'])!,
      dayInChapter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_in_chapter'])!,
      roundsCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rounds_completed'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ChapterProgressTable createAlias(String alias) {
    return $ChapterProgressTable(attachedDatabase, alias);
  }
}

class ChapterProgressEntry extends DataClass
    implements Insertable<ChapterProgressEntry> {
  final String userId;
  final String seasonId;
  final String chapterId;
  final int dayInChapter;
  final int roundsCompleted;
  final int startedAt;
  final int? completedAt;
  final int updatedAt;
  const ChapterProgressEntry(
      {required this.userId,
      required this.seasonId,
      required this.chapterId,
      required this.dayInChapter,
      required this.roundsCompleted,
      required this.startedAt,
      this.completedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['season_id'] = Variable<String>(seasonId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['day_in_chapter'] = Variable<int>(dayInChapter);
    map['rounds_completed'] = Variable<int>(roundsCompleted);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ChapterProgressCompanion toCompanion(bool nullToAbsent) {
    return ChapterProgressCompanion(
      userId: Value(userId),
      seasonId: Value(seasonId),
      chapterId: Value(chapterId),
      dayInChapter: Value(dayInChapter),
      roundsCompleted: Value(roundsCompleted),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterProgressEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterProgressEntry(
      userId: serializer.fromJson<String>(json['userId']),
      seasonId: serializer.fromJson<String>(json['seasonId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      dayInChapter: serializer.fromJson<int>(json['dayInChapter']),
      roundsCompleted: serializer.fromJson<int>(json['roundsCompleted']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'seasonId': serializer.toJson<String>(seasonId),
      'chapterId': serializer.toJson<String>(chapterId),
      'dayInChapter': serializer.toJson<int>(dayInChapter),
      'roundsCompleted': serializer.toJson<int>(roundsCompleted),
      'startedAt': serializer.toJson<int>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ChapterProgressEntry copyWith(
          {String? userId,
          String? seasonId,
          String? chapterId,
          int? dayInChapter,
          int? roundsCompleted,
          int? startedAt,
          Value<int?> completedAt = const Value.absent(),
          int? updatedAt}) =>
      ChapterProgressEntry(
        userId: userId ?? this.userId,
        seasonId: seasonId ?? this.seasonId,
        chapterId: chapterId ?? this.chapterId,
        dayInChapter: dayInChapter ?? this.dayInChapter,
        roundsCompleted: roundsCompleted ?? this.roundsCompleted,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ChapterProgressEntry copyWithCompanion(ChapterProgressCompanion data) {
    return ChapterProgressEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      seasonId: data.seasonId.present ? data.seasonId.value : this.seasonId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      dayInChapter: data.dayInChapter.present
          ? data.dayInChapter.value
          : this.dayInChapter,
      roundsCompleted: data.roundsCompleted.present
          ? data.roundsCompleted.value
          : this.roundsCompleted,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterProgressEntry(')
          ..write('userId: $userId, ')
          ..write('seasonId: $seasonId, ')
          ..write('chapterId: $chapterId, ')
          ..write('dayInChapter: $dayInChapter, ')
          ..write('roundsCompleted: $roundsCompleted, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, seasonId, chapterId, dayInChapter,
      roundsCompleted, startedAt, completedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterProgressEntry &&
          other.userId == this.userId &&
          other.seasonId == this.seasonId &&
          other.chapterId == this.chapterId &&
          other.dayInChapter == this.dayInChapter &&
          other.roundsCompleted == this.roundsCompleted &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt);
}

class ChapterProgressCompanion extends UpdateCompanion<ChapterProgressEntry> {
  final Value<String> userId;
  final Value<String> seasonId;
  final Value<String> chapterId;
  final Value<int> dayInChapter;
  final Value<int> roundsCompleted;
  final Value<int> startedAt;
  final Value<int?> completedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ChapterProgressCompanion({
    this.userId = const Value.absent(),
    this.seasonId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.dayInChapter = const Value.absent(),
    this.roundsCompleted = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterProgressCompanion.insert({
    this.userId = const Value.absent(),
    required String seasonId,
    required String chapterId,
    this.dayInChapter = const Value.absent(),
    this.roundsCompleted = const Value.absent(),
    required int startedAt,
    this.completedAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : seasonId = Value(seasonId),
        chapterId = Value(chapterId),
        startedAt = Value(startedAt),
        updatedAt = Value(updatedAt);
  static Insertable<ChapterProgressEntry> custom({
    Expression<String>? userId,
    Expression<String>? seasonId,
    Expression<String>? chapterId,
    Expression<int>? dayInChapter,
    Expression<int>? roundsCompleted,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (seasonId != null) 'season_id': seasonId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (dayInChapter != null) 'day_in_chapter': dayInChapter,
      if (roundsCompleted != null) 'rounds_completed': roundsCompleted,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterProgressCompanion copyWith(
      {Value<String>? userId,
      Value<String>? seasonId,
      Value<String>? chapterId,
      Value<int>? dayInChapter,
      Value<int>? roundsCompleted,
      Value<int>? startedAt,
      Value<int?>? completedAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return ChapterProgressCompanion(
      userId: userId ?? this.userId,
      seasonId: seasonId ?? this.seasonId,
      chapterId: chapterId ?? this.chapterId,
      dayInChapter: dayInChapter ?? this.dayInChapter,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (seasonId.present) {
      map['season_id'] = Variable<String>(seasonId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (dayInChapter.present) {
      map['day_in_chapter'] = Variable<int>(dayInChapter.value);
    }
    if (roundsCompleted.present) {
      map['rounds_completed'] = Variable<int>(roundsCompleted.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterProgressCompanion(')
          ..write('userId: $userId, ')
          ..write('seasonId: $seasonId, ')
          ..write('chapterId: $chapterId, ')
          ..write('dayInChapter: $dayInChapter, ')
          ..write('roundsCompleted: $roundsCompleted, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyRoundsTable extends DailyRounds
    with TableInfo<$DailyRoundsTable, DailyRoundEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyRoundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _dateIsoMeta =
      const VerificationMeta('dateIso');
  @override
  late final GeneratedColumn<String> dateIso = GeneratedColumn<String>(
      'date_iso', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
      'chapter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dayInChapterMeta =
      const VerificationMeta('dayInChapter');
  @override
  late final GeneratedColumn<int> dayInChapter = GeneratedColumn<int>(
      'day_in_chapter', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cardIdsJsonMeta =
      const VerificationMeta('cardIdsJson');
  @override
  late final GeneratedColumn<String> cardIdsJson = GeneratedColumn<String>(
      'card_ids_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _triviaJsonMeta =
      const VerificationMeta('triviaJson');
  @override
  late final GeneratedColumn<String> triviaJson = GeneratedColumn<String>(
      'trivia_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _gradesJsonMeta =
      const VerificationMeta('gradesJson');
  @override
  late final GeneratedColumn<String> gradesJson = GeneratedColumn<String>(
      'grades_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _answersJsonMeta =
      const VerificationMeta('answersJson');
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
      'answers_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
      'phase', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cards'));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        dateIso,
        chapterId,
        dayInChapter,
        cardIdsJson,
        triviaJson,
        gradesJson,
        answersJson,
        phase,
        startedAt,
        completedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_rounds';
  @override
  VerificationContext validateIntegrity(Insertable<DailyRoundEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('date_iso')) {
      context.handle(_dateIsoMeta,
          dateIso.isAcceptableOrUnknown(data['date_iso']!, _dateIsoMeta));
    } else if (isInserting) {
      context.missing(_dateIsoMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('day_in_chapter')) {
      context.handle(
          _dayInChapterMeta,
          dayInChapter.isAcceptableOrUnknown(
              data['day_in_chapter']!, _dayInChapterMeta));
    } else if (isInserting) {
      context.missing(_dayInChapterMeta);
    }
    if (data.containsKey('card_ids_json')) {
      context.handle(
          _cardIdsJsonMeta,
          cardIdsJson.isAcceptableOrUnknown(
              data['card_ids_json']!, _cardIdsJsonMeta));
    }
    if (data.containsKey('trivia_json')) {
      context.handle(
          _triviaJsonMeta,
          triviaJson.isAcceptableOrUnknown(
              data['trivia_json']!, _triviaJsonMeta));
    }
    if (data.containsKey('grades_json')) {
      context.handle(
          _gradesJsonMeta,
          gradesJson.isAcceptableOrUnknown(
              data['grades_json']!, _gradesJsonMeta));
    }
    if (data.containsKey('answers_json')) {
      context.handle(
          _answersJsonMeta,
          answersJson.isAcceptableOrUnknown(
              data['answers_json']!, _answersJsonMeta));
    }
    if (data.containsKey('phase')) {
      context.handle(
          _phaseMeta, phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, dateIso};
  @override
  DailyRoundEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyRoundEntry(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      dateIso: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_iso'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_id'])!,
      dayInChapter: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_in_chapter'])!,
      cardIdsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_ids_json'])!,
      triviaJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trivia_json'])!,
      gradesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grades_json'])!,
      answersJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}answers_json'])!,
      phase: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phase'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DailyRoundsTable createAlias(String alias) {
    return $DailyRoundsTable(attachedDatabase, alias);
  }
}

class DailyRoundEntry extends DataClass implements Insertable<DailyRoundEntry> {
  final String userId;
  final String dateIso;
  final String chapterId;
  final int dayInChapter;
  final String cardIdsJson;
  final String triviaJson;
  final String gradesJson;
  final String answersJson;
  final String phase;
  final int startedAt;
  final int? completedAt;
  final int updatedAt;
  const DailyRoundEntry(
      {required this.userId,
      required this.dateIso,
      required this.chapterId,
      required this.dayInChapter,
      required this.cardIdsJson,
      required this.triviaJson,
      required this.gradesJson,
      required this.answersJson,
      required this.phase,
      required this.startedAt,
      this.completedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['date_iso'] = Variable<String>(dateIso);
    map['chapter_id'] = Variable<String>(chapterId);
    map['day_in_chapter'] = Variable<int>(dayInChapter);
    map['card_ids_json'] = Variable<String>(cardIdsJson);
    map['trivia_json'] = Variable<String>(triviaJson);
    map['grades_json'] = Variable<String>(gradesJson);
    map['answers_json'] = Variable<String>(answersJson);
    map['phase'] = Variable<String>(phase);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DailyRoundsCompanion toCompanion(bool nullToAbsent) {
    return DailyRoundsCompanion(
      userId: Value(userId),
      dateIso: Value(dateIso),
      chapterId: Value(chapterId),
      dayInChapter: Value(dayInChapter),
      cardIdsJson: Value(cardIdsJson),
      triviaJson: Value(triviaJson),
      gradesJson: Value(gradesJson),
      answersJson: Value(answersJson),
      phase: Value(phase),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DailyRoundEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyRoundEntry(
      userId: serializer.fromJson<String>(json['userId']),
      dateIso: serializer.fromJson<String>(json['dateIso']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      dayInChapter: serializer.fromJson<int>(json['dayInChapter']),
      cardIdsJson: serializer.fromJson<String>(json['cardIdsJson']),
      triviaJson: serializer.fromJson<String>(json['triviaJson']),
      gradesJson: serializer.fromJson<String>(json['gradesJson']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      phase: serializer.fromJson<String>(json['phase']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'dateIso': serializer.toJson<String>(dateIso),
      'chapterId': serializer.toJson<String>(chapterId),
      'dayInChapter': serializer.toJson<int>(dayInChapter),
      'cardIdsJson': serializer.toJson<String>(cardIdsJson),
      'triviaJson': serializer.toJson<String>(triviaJson),
      'gradesJson': serializer.toJson<String>(gradesJson),
      'answersJson': serializer.toJson<String>(answersJson),
      'phase': serializer.toJson<String>(phase),
      'startedAt': serializer.toJson<int>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DailyRoundEntry copyWith(
          {String? userId,
          String? dateIso,
          String? chapterId,
          int? dayInChapter,
          String? cardIdsJson,
          String? triviaJson,
          String? gradesJson,
          String? answersJson,
          String? phase,
          int? startedAt,
          Value<int?> completedAt = const Value.absent(),
          int? updatedAt}) =>
      DailyRoundEntry(
        userId: userId ?? this.userId,
        dateIso: dateIso ?? this.dateIso,
        chapterId: chapterId ?? this.chapterId,
        dayInChapter: dayInChapter ?? this.dayInChapter,
        cardIdsJson: cardIdsJson ?? this.cardIdsJson,
        triviaJson: triviaJson ?? this.triviaJson,
        gradesJson: gradesJson ?? this.gradesJson,
        answersJson: answersJson ?? this.answersJson,
        phase: phase ?? this.phase,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DailyRoundEntry copyWithCompanion(DailyRoundsCompanion data) {
    return DailyRoundEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      dateIso: data.dateIso.present ? data.dateIso.value : this.dateIso,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      dayInChapter: data.dayInChapter.present
          ? data.dayInChapter.value
          : this.dayInChapter,
      cardIdsJson:
          data.cardIdsJson.present ? data.cardIdsJson.value : this.cardIdsJson,
      triviaJson:
          data.triviaJson.present ? data.triviaJson.value : this.triviaJson,
      gradesJson:
          data.gradesJson.present ? data.gradesJson.value : this.gradesJson,
      answersJson:
          data.answersJson.present ? data.answersJson.value : this.answersJson,
      phase: data.phase.present ? data.phase.value : this.phase,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyRoundEntry(')
          ..write('userId: $userId, ')
          ..write('dateIso: $dateIso, ')
          ..write('chapterId: $chapterId, ')
          ..write('dayInChapter: $dayInChapter, ')
          ..write('cardIdsJson: $cardIdsJson, ')
          ..write('triviaJson: $triviaJson, ')
          ..write('gradesJson: $gradesJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('phase: $phase, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId,
      dateIso,
      chapterId,
      dayInChapter,
      cardIdsJson,
      triviaJson,
      gradesJson,
      answersJson,
      phase,
      startedAt,
      completedAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyRoundEntry &&
          other.userId == this.userId &&
          other.dateIso == this.dateIso &&
          other.chapterId == this.chapterId &&
          other.dayInChapter == this.dayInChapter &&
          other.cardIdsJson == this.cardIdsJson &&
          other.triviaJson == this.triviaJson &&
          other.gradesJson == this.gradesJson &&
          other.answersJson == this.answersJson &&
          other.phase == this.phase &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt);
}

class DailyRoundsCompanion extends UpdateCompanion<DailyRoundEntry> {
  final Value<String> userId;
  final Value<String> dateIso;
  final Value<String> chapterId;
  final Value<int> dayInChapter;
  final Value<String> cardIdsJson;
  final Value<String> triviaJson;
  final Value<String> gradesJson;
  final Value<String> answersJson;
  final Value<String> phase;
  final Value<int> startedAt;
  final Value<int?> completedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DailyRoundsCompanion({
    this.userId = const Value.absent(),
    this.dateIso = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.dayInChapter = const Value.absent(),
    this.cardIdsJson = const Value.absent(),
    this.triviaJson = const Value.absent(),
    this.gradesJson = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.phase = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyRoundsCompanion.insert({
    this.userId = const Value.absent(),
    required String dateIso,
    required String chapterId,
    required int dayInChapter,
    this.cardIdsJson = const Value.absent(),
    this.triviaJson = const Value.absent(),
    this.gradesJson = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.phase = const Value.absent(),
    required int startedAt,
    this.completedAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : dateIso = Value(dateIso),
        chapterId = Value(chapterId),
        dayInChapter = Value(dayInChapter),
        startedAt = Value(startedAt),
        updatedAt = Value(updatedAt);
  static Insertable<DailyRoundEntry> custom({
    Expression<String>? userId,
    Expression<String>? dateIso,
    Expression<String>? chapterId,
    Expression<int>? dayInChapter,
    Expression<String>? cardIdsJson,
    Expression<String>? triviaJson,
    Expression<String>? gradesJson,
    Expression<String>? answersJson,
    Expression<String>? phase,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (dateIso != null) 'date_iso': dateIso,
      if (chapterId != null) 'chapter_id': chapterId,
      if (dayInChapter != null) 'day_in_chapter': dayInChapter,
      if (cardIdsJson != null) 'card_ids_json': cardIdsJson,
      if (triviaJson != null) 'trivia_json': triviaJson,
      if (gradesJson != null) 'grades_json': gradesJson,
      if (answersJson != null) 'answers_json': answersJson,
      if (phase != null) 'phase': phase,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyRoundsCompanion copyWith(
      {Value<String>? userId,
      Value<String>? dateIso,
      Value<String>? chapterId,
      Value<int>? dayInChapter,
      Value<String>? cardIdsJson,
      Value<String>? triviaJson,
      Value<String>? gradesJson,
      Value<String>? answersJson,
      Value<String>? phase,
      Value<int>? startedAt,
      Value<int?>? completedAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return DailyRoundsCompanion(
      userId: userId ?? this.userId,
      dateIso: dateIso ?? this.dateIso,
      chapterId: chapterId ?? this.chapterId,
      dayInChapter: dayInChapter ?? this.dayInChapter,
      cardIdsJson: cardIdsJson ?? this.cardIdsJson,
      triviaJson: triviaJson ?? this.triviaJson,
      gradesJson: gradesJson ?? this.gradesJson,
      answersJson: answersJson ?? this.answersJson,
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dateIso.present) {
      map['date_iso'] = Variable<String>(dateIso.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (dayInChapter.present) {
      map['day_in_chapter'] = Variable<int>(dayInChapter.value);
    }
    if (cardIdsJson.present) {
      map['card_ids_json'] = Variable<String>(cardIdsJson.value);
    }
    if (triviaJson.present) {
      map['trivia_json'] = Variable<String>(triviaJson.value);
    }
    if (gradesJson.present) {
      map['grades_json'] = Variable<String>(gradesJson.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyRoundsCompanion(')
          ..write('userId: $userId, ')
          ..write('dateIso: $dateIso, ')
          ..write('chapterId: $chapterId, ')
          ..write('dayInChapter: $dayInChapter, ')
          ..write('cardIdsJson: $cardIdsJson, ')
          ..write('triviaJson: $triviaJson, ')
          ..write('gradesJson: $gradesJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('phase: $phase, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoliticianBiosTable extends PoliticianBios
    with TableInfo<$PoliticianBiosTable, PoliticianBio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoliticianBiosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
      'card_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wikidataQidMeta =
      const VerificationMeta('wikidataQid');
  @override
  late final GeneratedColumn<String> wikidataQid = GeneratedColumn<String>(
      'wikidata_qid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _wikipediaTitleMeta =
      const VerificationMeta('wikipediaTitle');
  @override
  late final GeneratedColumn<String> wikipediaTitle = GeneratedColumn<String>(
      'wikipedia_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _wikipediaUrlMeta =
      const VerificationMeta('wikipediaUrl');
  @override
  late final GeneratedColumn<String> wikipediaUrl = GeneratedColumn<String>(
      'wikipedia_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bioExtractMeta =
      const VerificationMeta('bioExtract');
  @override
  late final GeneratedColumn<String> bioExtract = GeneratedColumn<String>(
      'bio_extract', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
      'fetched_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<int> lastError = GeneratedColumn<int>(
      'last_error', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMessageMeta =
      const VerificationMeta('lastErrorMessage');
  @override
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
      'last_error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        cardId,
        wikidataQid,
        wikipediaTitle,
        wikipediaUrl,
        bioExtract,
        fetchedAt,
        lastError,
        lastErrorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'politician_bios';
  @override
  VerificationContext validateIntegrity(Insertable<PoliticianBio> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta,
          cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('wikidata_qid')) {
      context.handle(
          _wikidataQidMeta,
          wikidataQid.isAcceptableOrUnknown(
              data['wikidata_qid']!, _wikidataQidMeta));
    }
    if (data.containsKey('wikipedia_title')) {
      context.handle(
          _wikipediaTitleMeta,
          wikipediaTitle.isAcceptableOrUnknown(
              data['wikipedia_title']!, _wikipediaTitleMeta));
    }
    if (data.containsKey('wikipedia_url')) {
      context.handle(
          _wikipediaUrlMeta,
          wikipediaUrl.isAcceptableOrUnknown(
              data['wikipedia_url']!, _wikipediaUrlMeta));
    }
    if (data.containsKey('bio_extract')) {
      context.handle(
          _bioExtractMeta,
          bioExtract.isAcceptableOrUnknown(
              data['bio_extract']!, _bioExtractMeta));
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
          _lastErrorMessageMeta,
          lastErrorMessage.isAcceptableOrUnknown(
              data['last_error_message']!, _lastErrorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  PoliticianBio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoliticianBio(
      cardId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_id'])!,
      wikidataQid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wikidata_qid']),
      wikipediaTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wikipedia_title']),
      wikipediaUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wikipedia_url']),
      bioExtract: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bio_extract']),
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fetched_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_error']),
      lastErrorMessage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_error_message']),
    );
  }

  @override
  $PoliticianBiosTable createAlias(String alias) {
    return $PoliticianBiosTable(attachedDatabase, alias);
  }
}

class PoliticianBio extends DataClass implements Insertable<PoliticianBio> {
  final String cardId;
  final String? wikidataQid;
  final String? wikipediaTitle;
  final String? wikipediaUrl;
  final String? bioExtract;
  final int? fetchedAt;
  final int? lastError;
  final String? lastErrorMessage;
  const PoliticianBio(
      {required this.cardId,
      this.wikidataQid,
      this.wikipediaTitle,
      this.wikipediaUrl,
      this.bioExtract,
      this.fetchedAt,
      this.lastError,
      this.lastErrorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<String>(cardId);
    if (!nullToAbsent || wikidataQid != null) {
      map['wikidata_qid'] = Variable<String>(wikidataQid);
    }
    if (!nullToAbsent || wikipediaTitle != null) {
      map['wikipedia_title'] = Variable<String>(wikipediaTitle);
    }
    if (!nullToAbsent || wikipediaUrl != null) {
      map['wikipedia_url'] = Variable<String>(wikipediaUrl);
    }
    if (!nullToAbsent || bioExtract != null) {
      map['bio_extract'] = Variable<String>(bioExtract);
    }
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<int>(fetchedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<int>(lastError);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    return map;
  }

  PoliticianBiosCompanion toCompanion(bool nullToAbsent) {
    return PoliticianBiosCompanion(
      cardId: Value(cardId),
      wikidataQid: wikidataQid == null && nullToAbsent
          ? const Value.absent()
          : Value(wikidataQid),
      wikipediaTitle: wikipediaTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(wikipediaTitle),
      wikipediaUrl: wikipediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(wikipediaUrl),
      bioExtract: bioExtract == null && nullToAbsent
          ? const Value.absent()
          : Value(bioExtract),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorMessage),
    );
  }

  factory PoliticianBio.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoliticianBio(
      cardId: serializer.fromJson<String>(json['cardId']),
      wikidataQid: serializer.fromJson<String?>(json['wikidataQid']),
      wikipediaTitle: serializer.fromJson<String?>(json['wikipediaTitle']),
      wikipediaUrl: serializer.fromJson<String?>(json['wikipediaUrl']),
      bioExtract: serializer.fromJson<String?>(json['bioExtract']),
      fetchedAt: serializer.fromJson<int?>(json['fetchedAt']),
      lastError: serializer.fromJson<int?>(json['lastError']),
      lastErrorMessage: serializer.fromJson<String?>(json['lastErrorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<String>(cardId),
      'wikidataQid': serializer.toJson<String?>(wikidataQid),
      'wikipediaTitle': serializer.toJson<String?>(wikipediaTitle),
      'wikipediaUrl': serializer.toJson<String?>(wikipediaUrl),
      'bioExtract': serializer.toJson<String?>(bioExtract),
      'fetchedAt': serializer.toJson<int?>(fetchedAt),
      'lastError': serializer.toJson<int?>(lastError),
      'lastErrorMessage': serializer.toJson<String?>(lastErrorMessage),
    };
  }

  PoliticianBio copyWith(
          {String? cardId,
          Value<String?> wikidataQid = const Value.absent(),
          Value<String?> wikipediaTitle = const Value.absent(),
          Value<String?> wikipediaUrl = const Value.absent(),
          Value<String?> bioExtract = const Value.absent(),
          Value<int?> fetchedAt = const Value.absent(),
          Value<int?> lastError = const Value.absent(),
          Value<String?> lastErrorMessage = const Value.absent()}) =>
      PoliticianBio(
        cardId: cardId ?? this.cardId,
        wikidataQid: wikidataQid.present ? wikidataQid.value : this.wikidataQid,
        wikipediaTitle:
            wikipediaTitle.present ? wikipediaTitle.value : this.wikipediaTitle,
        wikipediaUrl:
            wikipediaUrl.present ? wikipediaUrl.value : this.wikipediaUrl,
        bioExtract: bioExtract.present ? bioExtract.value : this.bioExtract,
        fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        lastErrorMessage: lastErrorMessage.present
            ? lastErrorMessage.value
            : this.lastErrorMessage,
      );
  PoliticianBio copyWithCompanion(PoliticianBiosCompanion data) {
    return PoliticianBio(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      wikidataQid:
          data.wikidataQid.present ? data.wikidataQid.value : this.wikidataQid,
      wikipediaTitle: data.wikipediaTitle.present
          ? data.wikipediaTitle.value
          : this.wikipediaTitle,
      wikipediaUrl: data.wikipediaUrl.present
          ? data.wikipediaUrl.value
          : this.wikipediaUrl,
      bioExtract:
          data.bioExtract.present ? data.bioExtract.value : this.bioExtract,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastErrorMessage: data.lastErrorMessage.present
          ? data.lastErrorMessage.value
          : this.lastErrorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoliticianBio(')
          ..write('cardId: $cardId, ')
          ..write('wikidataQid: $wikidataQid, ')
          ..write('wikipediaTitle: $wikipediaTitle, ')
          ..write('wikipediaUrl: $wikipediaUrl, ')
          ..write('bioExtract: $bioExtract, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastError: $lastError, ')
          ..write('lastErrorMessage: $lastErrorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, wikidataQid, wikipediaTitle,
      wikipediaUrl, bioExtract, fetchedAt, lastError, lastErrorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoliticianBio &&
          other.cardId == this.cardId &&
          other.wikidataQid == this.wikidataQid &&
          other.wikipediaTitle == this.wikipediaTitle &&
          other.wikipediaUrl == this.wikipediaUrl &&
          other.bioExtract == this.bioExtract &&
          other.fetchedAt == this.fetchedAt &&
          other.lastError == this.lastError &&
          other.lastErrorMessage == this.lastErrorMessage);
}

class PoliticianBiosCompanion extends UpdateCompanion<PoliticianBio> {
  final Value<String> cardId;
  final Value<String?> wikidataQid;
  final Value<String?> wikipediaTitle;
  final Value<String?> wikipediaUrl;
  final Value<String?> bioExtract;
  final Value<int?> fetchedAt;
  final Value<int?> lastError;
  final Value<String?> lastErrorMessage;
  final Value<int> rowid;
  const PoliticianBiosCompanion({
    this.cardId = const Value.absent(),
    this.wikidataQid = const Value.absent(),
    this.wikipediaTitle = const Value.absent(),
    this.wikipediaUrl = const Value.absent(),
    this.bioExtract = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoliticianBiosCompanion.insert({
    required String cardId,
    this.wikidataQid = const Value.absent(),
    this.wikipediaTitle = const Value.absent(),
    this.wikipediaUrl = const Value.absent(),
    this.bioExtract = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId);
  static Insertable<PoliticianBio> custom({
    Expression<String>? cardId,
    Expression<String>? wikidataQid,
    Expression<String>? wikipediaTitle,
    Expression<String>? wikipediaUrl,
    Expression<String>? bioExtract,
    Expression<int>? fetchedAt,
    Expression<int>? lastError,
    Expression<String>? lastErrorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (wikidataQid != null) 'wikidata_qid': wikidataQid,
      if (wikipediaTitle != null) 'wikipedia_title': wikipediaTitle,
      if (wikipediaUrl != null) 'wikipedia_url': wikipediaUrl,
      if (bioExtract != null) 'bio_extract': bioExtract,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastError != null) 'last_error': lastError,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoliticianBiosCompanion copyWith(
      {Value<String>? cardId,
      Value<String?>? wikidataQid,
      Value<String?>? wikipediaTitle,
      Value<String?>? wikipediaUrl,
      Value<String?>? bioExtract,
      Value<int?>? fetchedAt,
      Value<int?>? lastError,
      Value<String?>? lastErrorMessage,
      Value<int>? rowid}) {
    return PoliticianBiosCompanion(
      cardId: cardId ?? this.cardId,
      wikidataQid: wikidataQid ?? this.wikidataQid,
      wikipediaTitle: wikipediaTitle ?? this.wikipediaTitle,
      wikipediaUrl: wikipediaUrl ?? this.wikipediaUrl,
      bioExtract: bioExtract ?? this.bioExtract,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastError: lastError ?? this.lastError,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (wikidataQid.present) {
      map['wikidata_qid'] = Variable<String>(wikidataQid.value);
    }
    if (wikipediaTitle.present) {
      map['wikipedia_title'] = Variable<String>(wikipediaTitle.value);
    }
    if (wikipediaUrl.present) {
      map['wikipedia_url'] = Variable<String>(wikipediaUrl.value);
    }
    if (bioExtract.present) {
      map['bio_extract'] = Variable<String>(bioExtract.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<int>(lastError.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoliticianBiosCompanion(')
          ..write('cardId: $cardId, ')
          ..write('wikidataQid: $wikidataQid, ')
          ..write('wikipediaTitle: $wikipediaTitle, ')
          ..write('wikipediaUrl: $wikipediaUrl, ')
          ..write('bioExtract: $bioExtract, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastError: $lastError, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletedRunsTable extends CompletedRuns
    with TableInfo<$CompletedRunsTable, CompletedRunEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletedRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local-user'));
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
      'score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _correctCountMeta =
      const VerificationMeta('correctCount');
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
      'correct_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _totalCountMeta =
      const VerificationMeta('totalCount');
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
      'total_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        mode,
        completedAt,
        durationMs,
        score,
        correctCount,
        totalCount,
        summary,
        payload
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completed_runs';
  @override
  VerificationContext validateIntegrity(Insertable<CompletedRunEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    if (data.containsKey('correct_count')) {
      context.handle(
          _correctCountMeta,
          correctCount.isAcceptableOrUnknown(
              data['correct_count']!, _correctCountMeta));
    }
    if (data.containsKey('total_count')) {
      context.handle(
          _totalCountMeta,
          totalCount.isAcceptableOrUnknown(
              data['total_count']!, _totalCountMeta));
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletedRunEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletedRunEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_at'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}score']),
      correctCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}correct_count']),
      totalCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_count']),
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary']),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $CompletedRunsTable createAlias(String alias) {
    return $CompletedRunsTable(attachedDatabase, alias);
  }
}

class CompletedRunEntry extends DataClass
    implements Insertable<CompletedRunEntry> {
  final String id;
  final String userId;
  final String mode;
  final int completedAt;
  final int? durationMs;
  final int? score;
  final int? correctCount;
  final int? totalCount;
  final String? summary;
  final String payload;
  const CompletedRunEntry(
      {required this.id,
      required this.userId,
      required this.mode,
      required this.completedAt,
      this.durationMs,
      this.score,
      this.correctCount,
      this.totalCount,
      this.summary,
      required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['mode'] = Variable<String>(mode);
    map['completed_at'] = Variable<int>(completedAt);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    if (!nullToAbsent || correctCount != null) {
      map['correct_count'] = Variable<int>(correctCount);
    }
    if (!nullToAbsent || totalCount != null) {
      map['total_count'] = Variable<int>(totalCount);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CompletedRunsCompanion toCompanion(bool nullToAbsent) {
    return CompletedRunsCompanion(
      id: Value(id),
      userId: Value(userId),
      mode: Value(mode),
      completedAt: Value(completedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
      correctCount: correctCount == null && nullToAbsent
          ? const Value.absent()
          : Value(correctCount),
      totalCount: totalCount == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCount),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      payload: Value(payload),
    );
  }

  factory CompletedRunEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletedRunEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      mode: serializer.fromJson<String>(json['mode']),
      completedAt: serializer.fromJson<int>(json['completedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      score: serializer.fromJson<int?>(json['score']),
      correctCount: serializer.fromJson<int?>(json['correctCount']),
      totalCount: serializer.fromJson<int?>(json['totalCount']),
      summary: serializer.fromJson<String?>(json['summary']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'mode': serializer.toJson<String>(mode),
      'completedAt': serializer.toJson<int>(completedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'score': serializer.toJson<int?>(score),
      'correctCount': serializer.toJson<int?>(correctCount),
      'totalCount': serializer.toJson<int?>(totalCount),
      'summary': serializer.toJson<String?>(summary),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CompletedRunEntry copyWith(
          {String? id,
          String? userId,
          String? mode,
          int? completedAt,
          Value<int?> durationMs = const Value.absent(),
          Value<int?> score = const Value.absent(),
          Value<int?> correctCount = const Value.absent(),
          Value<int?> totalCount = const Value.absent(),
          Value<String?> summary = const Value.absent(),
          String? payload}) =>
      CompletedRunEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        mode: mode ?? this.mode,
        completedAt: completedAt ?? this.completedAt,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        score: score.present ? score.value : this.score,
        correctCount:
            correctCount.present ? correctCount.value : this.correctCount,
        totalCount: totalCount.present ? totalCount.value : this.totalCount,
        summary: summary.present ? summary.value : this.summary,
        payload: payload ?? this.payload,
      );
  CompletedRunEntry copyWithCompanion(CompletedRunsCompanion data) {
    return CompletedRunEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      mode: data.mode.present ? data.mode.value : this.mode,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      score: data.score.present ? data.score.value : this.score,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      totalCount:
          data.totalCount.present ? data.totalCount.value : this.totalCount,
      summary: data.summary.present ? data.summary.value : this.summary,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletedRunEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('mode: $mode, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('score: $score, ')
          ..write('correctCount: $correctCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('summary: $summary, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, mode, completedAt, durationMs,
      score, correctCount, totalCount, summary, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedRunEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.mode == this.mode &&
          other.completedAt == this.completedAt &&
          other.durationMs == this.durationMs &&
          other.score == this.score &&
          other.correctCount == this.correctCount &&
          other.totalCount == this.totalCount &&
          other.summary == this.summary &&
          other.payload == this.payload);
}

class CompletedRunsCompanion extends UpdateCompanion<CompletedRunEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> mode;
  final Value<int> completedAt;
  final Value<int?> durationMs;
  final Value<int?> score;
  final Value<int?> correctCount;
  final Value<int?> totalCount;
  final Value<String?> summary;
  final Value<String> payload;
  final Value<int> rowid;
  const CompletedRunsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.mode = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.score = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.summary = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletedRunsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String mode,
    required int completedAt,
    this.durationMs = const Value.absent(),
    this.score = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.summary = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mode = Value(mode),
        completedAt = Value(completedAt);
  static Insertable<CompletedRunEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? mode,
    Expression<int>? completedAt,
    Expression<int>? durationMs,
    Expression<int>? score,
    Expression<int>? correctCount,
    Expression<int>? totalCount,
    Expression<String>? summary,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (mode != null) 'mode': mode,
      if (completedAt != null) 'completed_at': completedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (score != null) 'score': score,
      if (correctCount != null) 'correct_count': correctCount,
      if (totalCount != null) 'total_count': totalCount,
      if (summary != null) 'summary': summary,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletedRunsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? mode,
      Value<int>? completedAt,
      Value<int?>? durationMs,
      Value<int?>? score,
      Value<int?>? correctCount,
      Value<int?>? totalCount,
      Value<String?>? summary,
      Value<String>? payload,
      Value<int>? rowid}) {
    return CompletedRunsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mode: mode ?? this.mode,
      completedAt: completedAt ?? this.completedAt,
      durationMs: durationMs ?? this.durationMs,
      score: score ?? this.score,
      correctCount: correctCount ?? this.correctCount,
      totalCount: totalCount ?? this.totalCount,
      summary: summary ?? this.summary,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletedRunsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('mode: $mode, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('score: $score, ')
          ..write('correctCount: $correctCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('summary: $summary, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEventsTable extends OutboxEvents
    with TableInfo<$OutboxEventsTable, OutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _questionIdMeta =
      const VerificationMeta('questionId');
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
      'question_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptIdMeta =
      const VerificationMeta('attemptId');
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
      'attempt_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chosenKeyMeta =
      const VerificationMeta('chosenKey');
  @override
  late final GeneratedColumn<String> chosenKey = GeneratedColumn<String>(
      'chosen_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<String> grade = GeneratedColumn<String>(
      'grade', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _clientTsMeta =
      const VerificationMeta('clientTs');
  @override
  late final GeneratedColumn<int> clientTs = GeneratedColumn<int>(
      'client_ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _triesMeta = const VerificationMeta('tries');
  @override
  late final GeneratedColumn<int> tries = GeneratedColumn<int>(
      'tries', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        eventId,
        type,
        questionId,
        attemptId,
        chosenKey,
        grade,
        payload,
        clientTs,
        tries,
        lastError,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_events';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
          _questionIdMeta,
          questionId.isAcceptableOrUnknown(
              data['question_id']!, _questionIdMeta));
    }
    if (data.containsKey('attempt_id')) {
      context.handle(_attemptIdMeta,
          attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta));
    }
    if (data.containsKey('chosen_key')) {
      context.handle(_chosenKeyMeta,
          chosenKey.isAcceptableOrUnknown(data['chosen_key']!, _chosenKeyMeta));
    }
    if (data.containsKey('grade')) {
      context.handle(
          _gradeMeta, grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('client_ts')) {
      context.handle(_clientTsMeta,
          clientTs.isAcceptableOrUnknown(data['client_ts']!, _clientTsMeta));
    } else if (isInserting) {
      context.missing(_clientTsMeta);
    }
    if (data.containsKey('tries')) {
      context.handle(
          _triesMeta, tries.isAcceptableOrUnknown(data['tries']!, _triesMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  OutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvent(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      questionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_id']),
      attemptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attempt_id']),
      chosenKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chosen_key']),
      grade: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grade']),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      clientTs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}client_ts'])!,
      tries: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tries'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxEventsTable createAlias(String alias) {
    return $OutboxEventsTable(attachedDatabase, alias);
  }
}

class OutboxEvent extends DataClass implements Insertable<OutboxEvent> {
  final String eventId;
  final String type;
  final String? questionId;
  final String? attemptId;
  final String? chosenKey;
  final String? grade;
  final String payload;
  final int clientTs;
  final int tries;
  final String? lastError;
  final int createdAt;
  const OutboxEvent(
      {required this.eventId,
      required this.type,
      this.questionId,
      this.attemptId,
      this.chosenKey,
      this.grade,
      required this.payload,
      required this.clientTs,
      required this.tries,
      this.lastError,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || questionId != null) {
      map['question_id'] = Variable<String>(questionId);
    }
    if (!nullToAbsent || attemptId != null) {
      map['attempt_id'] = Variable<String>(attemptId);
    }
    if (!nullToAbsent || chosenKey != null) {
      map['chosen_key'] = Variable<String>(chosenKey);
    }
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<String>(grade);
    }
    map['payload'] = Variable<String>(payload);
    map['client_ts'] = Variable<int>(clientTs);
    map['tries'] = Variable<int>(tries);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OutboxEventsCompanion toCompanion(bool nullToAbsent) {
    return OutboxEventsCompanion(
      eventId: Value(eventId),
      type: Value(type),
      questionId: questionId == null && nullToAbsent
          ? const Value.absent()
          : Value(questionId),
      attemptId: attemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(attemptId),
      chosenKey: chosenKey == null && nullToAbsent
          ? const Value.absent()
          : Value(chosenKey),
      grade:
          grade == null && nullToAbsent ? const Value.absent() : Value(grade),
      payload: Value(payload),
      clientTs: Value(clientTs),
      tries: Value(tries),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      type: serializer.fromJson<String>(json['type']),
      questionId: serializer.fromJson<String?>(json['questionId']),
      attemptId: serializer.fromJson<String?>(json['attemptId']),
      chosenKey: serializer.fromJson<String?>(json['chosenKey']),
      grade: serializer.fromJson<String?>(json['grade']),
      payload: serializer.fromJson<String>(json['payload']),
      clientTs: serializer.fromJson<int>(json['clientTs']),
      tries: serializer.fromJson<int>(json['tries']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'type': serializer.toJson<String>(type),
      'questionId': serializer.toJson<String?>(questionId),
      'attemptId': serializer.toJson<String?>(attemptId),
      'chosenKey': serializer.toJson<String?>(chosenKey),
      'grade': serializer.toJson<String?>(grade),
      'payload': serializer.toJson<String>(payload),
      'clientTs': serializer.toJson<int>(clientTs),
      'tries': serializer.toJson<int>(tries),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OutboxEvent copyWith(
          {String? eventId,
          String? type,
          Value<String?> questionId = const Value.absent(),
          Value<String?> attemptId = const Value.absent(),
          Value<String?> chosenKey = const Value.absent(),
          Value<String?> grade = const Value.absent(),
          String? payload,
          int? clientTs,
          int? tries,
          Value<String?> lastError = const Value.absent(),
          int? createdAt}) =>
      OutboxEvent(
        eventId: eventId ?? this.eventId,
        type: type ?? this.type,
        questionId: questionId.present ? questionId.value : this.questionId,
        attemptId: attemptId.present ? attemptId.value : this.attemptId,
        chosenKey: chosenKey.present ? chosenKey.value : this.chosenKey,
        grade: grade.present ? grade.value : this.grade,
        payload: payload ?? this.payload,
        clientTs: clientTs ?? this.clientTs,
        tries: tries ?? this.tries,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxEvent copyWithCompanion(OutboxEventsCompanion data) {
    return OutboxEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      type: data.type.present ? data.type.value : this.type,
      questionId:
          data.questionId.present ? data.questionId.value : this.questionId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      chosenKey: data.chosenKey.present ? data.chosenKey.value : this.chosenKey,
      grade: data.grade.present ? data.grade.value : this.grade,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientTs: data.clientTs.present ? data.clientTs.value : this.clientTs,
      tries: data.tries.present ? data.tries.value : this.tries,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvent(')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('questionId: $questionId, ')
          ..write('attemptId: $attemptId, ')
          ..write('chosenKey: $chosenKey, ')
          ..write('grade: $grade, ')
          ..write('payload: $payload, ')
          ..write('clientTs: $clientTs, ')
          ..write('tries: $tries, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, type, questionId, attemptId,
      chosenKey, grade, payload, clientTs, tries, lastError, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvent &&
          other.eventId == this.eventId &&
          other.type == this.type &&
          other.questionId == this.questionId &&
          other.attemptId == this.attemptId &&
          other.chosenKey == this.chosenKey &&
          other.grade == this.grade &&
          other.payload == this.payload &&
          other.clientTs == this.clientTs &&
          other.tries == this.tries &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxEventsCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<String> eventId;
  final Value<String> type;
  final Value<String?> questionId;
  final Value<String?> attemptId;
  final Value<String?> chosenKey;
  final Value<String?> grade;
  final Value<String> payload;
  final Value<int> clientTs;
  final Value<int> tries;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OutboxEventsCompanion({
    this.eventId = const Value.absent(),
    this.type = const Value.absent(),
    this.questionId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.chosenKey = const Value.absent(),
    this.grade = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientTs = const Value.absent(),
    this.tries = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEventsCompanion.insert({
    required String eventId,
    required String type,
    this.questionId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.chosenKey = const Value.absent(),
    this.grade = const Value.absent(),
    this.payload = const Value.absent(),
    required int clientTs,
    this.tries = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : eventId = Value(eventId),
        type = Value(type),
        clientTs = Value(clientTs),
        createdAt = Value(createdAt);
  static Insertable<OutboxEvent> custom({
    Expression<String>? eventId,
    Expression<String>? type,
    Expression<String>? questionId,
    Expression<String>? attemptId,
    Expression<String>? chosenKey,
    Expression<String>? grade,
    Expression<String>? payload,
    Expression<int>? clientTs,
    Expression<int>? tries,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (type != null) 'type': type,
      if (questionId != null) 'question_id': questionId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (chosenKey != null) 'chosen_key': chosenKey,
      if (grade != null) 'grade': grade,
      if (payload != null) 'payload': payload,
      if (clientTs != null) 'client_ts': clientTs,
      if (tries != null) 'tries': tries,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEventsCompanion copyWith(
      {Value<String>? eventId,
      Value<String>? type,
      Value<String?>? questionId,
      Value<String?>? attemptId,
      Value<String?>? chosenKey,
      Value<String?>? grade,
      Value<String>? payload,
      Value<int>? clientTs,
      Value<int>? tries,
      Value<String?>? lastError,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return OutboxEventsCompanion(
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      questionId: questionId ?? this.questionId,
      attemptId: attemptId ?? this.attemptId,
      chosenKey: chosenKey ?? this.chosenKey,
      grade: grade ?? this.grade,
      payload: payload ?? this.payload,
      clientTs: clientTs ?? this.clientTs,
      tries: tries ?? this.tries,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (chosenKey.present) {
      map['chosen_key'] = Variable<String>(chosenKey.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(grade.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientTs.present) {
      map['client_ts'] = Variable<int>(clientTs.value);
    }
    if (tries.present) {
      map['tries'] = Variable<int>(tries.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('questionId: $questionId, ')
          ..write('attemptId: $attemptId, ')
          ..write('chosenKey: $chosenKey, ')
          ..write('grade: $grade, ')
          ..write('payload: $payload, ')
          ..write('clientTs: $clientTs, ')
          ..write('tries: $tries, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FcleAnswersTable extends FcleAnswers
    with TableInfo<$FcleAnswersTable, FcleAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FcleAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _questionIdMeta =
      const VerificationMeta('questionId');
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
      'question_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
      'domain', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _correctMeta =
      const VerificationMeta('correct');
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
      'correct', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("correct" IN (0, 1))'));
  static const VerificationMeta _inMockMeta = const VerificationMeta('inMock');
  @override
  late final GeneratedColumn<bool> inMock = GeneratedColumn<bool>(
      'in_mock', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("in_mock" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _answeredAtMeta =
      const VerificationMeta('answeredAt');
  @override
  late final GeneratedColumn<int> answeredAt = GeneratedColumn<int>(
      'answered_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, questionId, domain, correct, inMock, answeredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fcle_answers';
  @override
  VerificationContext validateIntegrity(Insertable<FcleAnswer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_id')) {
      context.handle(
          _questionIdMeta,
          questionId.isAcceptableOrUnknown(
              data['question_id']!, _questionIdMeta));
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('domain')) {
      context.handle(_domainMeta,
          domain.isAcceptableOrUnknown(data['domain']!, _domainMeta));
    } else if (isInserting) {
      context.missing(_domainMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(_correctMeta,
          correct.isAcceptableOrUnknown(data['correct']!, _correctMeta));
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('in_mock')) {
      context.handle(_inMockMeta,
          inMock.isAcceptableOrUnknown(data['in_mock']!, _inMockMeta));
    }
    if (data.containsKey('answered_at')) {
      context.handle(
          _answeredAtMeta,
          answeredAt.isAcceptableOrUnknown(
              data['answered_at']!, _answeredAtMeta));
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FcleAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FcleAnswer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      questionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_id'])!,
      domain: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}domain'])!,
      correct: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}correct'])!,
      inMock: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}in_mock'])!,
      answeredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}answered_at'])!,
    );
  }

  @override
  $FcleAnswersTable createAlias(String alias) {
    return $FcleAnswersTable(attachedDatabase, alias);
  }
}

class FcleAnswer extends DataClass implements Insertable<FcleAnswer> {
  final int id;
  final String questionId;
  final String domain;
  final bool correct;
  final bool inMock;
  final int answeredAt;
  const FcleAnswer(
      {required this.id,
      required this.questionId,
      required this.domain,
      required this.correct,
      required this.inMock,
      required this.answeredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_id'] = Variable<String>(questionId);
    map['domain'] = Variable<String>(domain);
    map['correct'] = Variable<bool>(correct);
    map['in_mock'] = Variable<bool>(inMock);
    map['answered_at'] = Variable<int>(answeredAt);
    return map;
  }

  FcleAnswersCompanion toCompanion(bool nullToAbsent) {
    return FcleAnswersCompanion(
      id: Value(id),
      questionId: Value(questionId),
      domain: Value(domain),
      correct: Value(correct),
      inMock: Value(inMock),
      answeredAt: Value(answeredAt),
    );
  }

  factory FcleAnswer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FcleAnswer(
      id: serializer.fromJson<int>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      domain: serializer.fromJson<String>(json['domain']),
      correct: serializer.fromJson<bool>(json['correct']),
      inMock: serializer.fromJson<bool>(json['inMock']),
      answeredAt: serializer.fromJson<int>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionId': serializer.toJson<String>(questionId),
      'domain': serializer.toJson<String>(domain),
      'correct': serializer.toJson<bool>(correct),
      'inMock': serializer.toJson<bool>(inMock),
      'answeredAt': serializer.toJson<int>(answeredAt),
    };
  }

  FcleAnswer copyWith(
          {int? id,
          String? questionId,
          String? domain,
          bool? correct,
          bool? inMock,
          int? answeredAt}) =>
      FcleAnswer(
        id: id ?? this.id,
        questionId: questionId ?? this.questionId,
        domain: domain ?? this.domain,
        correct: correct ?? this.correct,
        inMock: inMock ?? this.inMock,
        answeredAt: answeredAt ?? this.answeredAt,
      );
  FcleAnswer copyWithCompanion(FcleAnswersCompanion data) {
    return FcleAnswer(
      id: data.id.present ? data.id.value : this.id,
      questionId:
          data.questionId.present ? data.questionId.value : this.questionId,
      domain: data.domain.present ? data.domain.value : this.domain,
      correct: data.correct.present ? data.correct.value : this.correct,
      inMock: data.inMock.present ? data.inMock.value : this.inMock,
      answeredAt:
          data.answeredAt.present ? data.answeredAt.value : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FcleAnswer(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('domain: $domain, ')
          ..write('correct: $correct, ')
          ..write('inMock: $inMock, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, questionId, domain, correct, inMock, answeredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FcleAnswer &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.domain == this.domain &&
          other.correct == this.correct &&
          other.inMock == this.inMock &&
          other.answeredAt == this.answeredAt);
}

class FcleAnswersCompanion extends UpdateCompanion<FcleAnswer> {
  final Value<int> id;
  final Value<String> questionId;
  final Value<String> domain;
  final Value<bool> correct;
  final Value<bool> inMock;
  final Value<int> answeredAt;
  const FcleAnswersCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.domain = const Value.absent(),
    this.correct = const Value.absent(),
    this.inMock = const Value.absent(),
    this.answeredAt = const Value.absent(),
  });
  FcleAnswersCompanion.insert({
    this.id = const Value.absent(),
    required String questionId,
    required String domain,
    required bool correct,
    this.inMock = const Value.absent(),
    required int answeredAt,
  })  : questionId = Value(questionId),
        domain = Value(domain),
        correct = Value(correct),
        answeredAt = Value(answeredAt);
  static Insertable<FcleAnswer> custom({
    Expression<int>? id,
    Expression<String>? questionId,
    Expression<String>? domain,
    Expression<bool>? correct,
    Expression<bool>? inMock,
    Expression<int>? answeredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (domain != null) 'domain': domain,
      if (correct != null) 'correct': correct,
      if (inMock != null) 'in_mock': inMock,
      if (answeredAt != null) 'answered_at': answeredAt,
    });
  }

  FcleAnswersCompanion copyWith(
      {Value<int>? id,
      Value<String>? questionId,
      Value<String>? domain,
      Value<bool>? correct,
      Value<bool>? inMock,
      Value<int>? answeredAt}) {
    return FcleAnswersCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      domain: domain ?? this.domain,
      correct: correct ?? this.correct,
      inMock: inMock ?? this.inMock,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (inMock.present) {
      map['in_mock'] = Variable<bool>(inMock.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<int>(answeredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FcleAnswersCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('domain: $domain, ')
          ..write('correct: $correct, ')
          ..write('inMock: $inMock, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GovNodesTable govNodes = $GovNodesTable(this);
  late final $GovEdgesTable govEdges = $GovEdgesTable(this);
  late final $LocalDecksTable localDecks = $LocalDecksTable(this);
  late final $LocalCardsTable localCards = $LocalCardsTable(this);
  late final $CardMemoryStatesTable cardMemoryStates =
      $CardMemoryStatesTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $UserNodeProgressTable userNodeProgress =
      $UserNodeProgressTable(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $ChapterProgressTable chapterProgress =
      $ChapterProgressTable(this);
  late final $DailyRoundsTable dailyRounds = $DailyRoundsTable(this);
  late final $PoliticianBiosTable politicianBios = $PoliticianBiosTable(this);
  late final $CompletedRunsTable completedRuns = $CompletedRunsTable(this);
  late final $OutboxEventsTable outboxEvents = $OutboxEventsTable(this);
  late final $FcleAnswersTable fcleAnswers = $FcleAnswersTable(this);
  late final CardsDao cardsDao = CardsDao(this as AppDatabase);
  late final ReviewsDao reviewsDao = ReviewsDao(this as AppDatabase);
  late final DecksDao decksDao = DecksDao(this as AppDatabase);
  late final GovernmentDao governmentDao = GovernmentDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final MetaDao metaDao = MetaDao(this as AppDatabase);
  late final ChapterProgressDao chapterProgressDao =
      ChapterProgressDao(this as AppDatabase);
  late final DailyRoundsDao dailyRoundsDao =
      DailyRoundsDao(this as AppDatabase);
  late final PoliticianBiosDao politicianBiosDao =
      PoliticianBiosDao(this as AppDatabase);
  late final CompletedRunsDao completedRunsDao =
      CompletedRunsDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final FcleAnswersDao fcleAnswersDao =
      FcleAnswersDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        govNodes,
        govEdges,
        localDecks,
        localCards,
        cardMemoryStates,
        reviewLogs,
        userNodeProgress,
        appMeta,
        chapterProgress,
        dailyRounds,
        politicianBios,
        completedRuns,
        outboxEvents,
        fcleAnswers
      ];
}

typedef $$GovNodesTableCreateCompanionBuilder = GovNodesCompanion Function({
  required String id,
  required String governmentId,
  required String externalId,
  required String name,
  Value<String?> shortName,
  Value<String?> description,
  required String nodeType,
  Value<bool> isHeadOfState,
  Value<bool> isHeadOfGovt,
  Value<bool?> isElected,
  Value<double?> mapX,
  Value<double?> mapY,
  Value<double?> mapWidth,
  Value<double?> mapHeight,
  Value<String> mapShape,
  Value<String?> mapIcon,
  Value<String?> mapColor,
  Value<String> mapLabelPos,
  required int tierOrder,
  Value<String> unlockRequires,
  Value<bool> isActive,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$GovNodesTableUpdateCompanionBuilder = GovNodesCompanion Function({
  Value<String> id,
  Value<String> governmentId,
  Value<String> externalId,
  Value<String> name,
  Value<String?> shortName,
  Value<String?> description,
  Value<String> nodeType,
  Value<bool> isHeadOfState,
  Value<bool> isHeadOfGovt,
  Value<bool?> isElected,
  Value<double?> mapX,
  Value<double?> mapY,
  Value<double?> mapWidth,
  Value<double?> mapHeight,
  Value<String> mapShape,
  Value<String?> mapIcon,
  Value<String?> mapColor,
  Value<String> mapLabelPos,
  Value<int> tierOrder,
  Value<String> unlockRequires,
  Value<bool> isActive,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$GovNodesTableFilterComposer
    extends Composer<_$AppDatabase, $GovNodesTable> {
  $$GovNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeType => $composableBuilder(
      column: $table.nodeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHeadOfState => $composableBuilder(
      column: $table.isHeadOfState, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHeadOfGovt => $composableBuilder(
      column: $table.isHeadOfGovt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isElected => $composableBuilder(
      column: $table.isElected, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mapX => $composableBuilder(
      column: $table.mapX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mapY => $composableBuilder(
      column: $table.mapY, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mapWidth => $composableBuilder(
      column: $table.mapWidth, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mapHeight => $composableBuilder(
      column: $table.mapHeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mapShape => $composableBuilder(
      column: $table.mapShape, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mapIcon => $composableBuilder(
      column: $table.mapIcon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mapColor => $composableBuilder(
      column: $table.mapColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mapLabelPos => $composableBuilder(
      column: $table.mapLabelPos, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tierOrder => $composableBuilder(
      column: $table.tierOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unlockRequires => $composableBuilder(
      column: $table.unlockRequires,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$GovNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $GovNodesTable> {
  $$GovNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get governmentId => $composableBuilder(
      column: $table.governmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeType => $composableBuilder(
      column: $table.nodeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHeadOfState => $composableBuilder(
      column: $table.isHeadOfState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHeadOfGovt => $composableBuilder(
      column: $table.isHeadOfGovt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isElected => $composableBuilder(
      column: $table.isElected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mapX => $composableBuilder(
      column: $table.mapX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mapY => $composableBuilder(
      column: $table.mapY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mapWidth => $composableBuilder(
      column: $table.mapWidth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mapHeight => $composableBuilder(
      column: $table.mapHeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mapShape => $composableBuilder(
      column: $table.mapShape, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mapIcon => $composableBuilder(
      column: $table.mapIcon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mapColor => $composableBuilder(
      column: $table.mapColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mapLabelPos => $composableBuilder(
      column: $table.mapLabelPos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tierOrder => $composableBuilder(
      column: $table.tierOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unlockRequires => $composableBuilder(
      column: $table.unlockRequires,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$GovNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GovNodesTable> {
  $$GovNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get nodeType =>
      $composableBuilder(column: $table.nodeType, builder: (column) => column);

  GeneratedColumn<bool> get isHeadOfState => $composableBuilder(
      column: $table.isHeadOfState, builder: (column) => column);

  GeneratedColumn<bool> get isHeadOfGovt => $composableBuilder(
      column: $table.isHeadOfGovt, builder: (column) => column);

  GeneratedColumn<bool> get isElected =>
      $composableBuilder(column: $table.isElected, builder: (column) => column);

  GeneratedColumn<double> get mapX =>
      $composableBuilder(column: $table.mapX, builder: (column) => column);

  GeneratedColumn<double> get mapY =>
      $composableBuilder(column: $table.mapY, builder: (column) => column);

  GeneratedColumn<double> get mapWidth =>
      $composableBuilder(column: $table.mapWidth, builder: (column) => column);

  GeneratedColumn<double> get mapHeight =>
      $composableBuilder(column: $table.mapHeight, builder: (column) => column);

  GeneratedColumn<String> get mapShape =>
      $composableBuilder(column: $table.mapShape, builder: (column) => column);

  GeneratedColumn<String> get mapIcon =>
      $composableBuilder(column: $table.mapIcon, builder: (column) => column);

  GeneratedColumn<String> get mapColor =>
      $composableBuilder(column: $table.mapColor, builder: (column) => column);

  GeneratedColumn<String> get mapLabelPos => $composableBuilder(
      column: $table.mapLabelPos, builder: (column) => column);

  GeneratedColumn<int> get tierOrder =>
      $composableBuilder(column: $table.tierOrder, builder: (column) => column);

  GeneratedColumn<String> get unlockRequires => $composableBuilder(
      column: $table.unlockRequires, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$GovNodesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GovNodesTable,
    GovNode,
    $$GovNodesTableFilterComposer,
    $$GovNodesTableOrderingComposer,
    $$GovNodesTableAnnotationComposer,
    $$GovNodesTableCreateCompanionBuilder,
    $$GovNodesTableUpdateCompanionBuilder,
    (GovNode, BaseReferences<_$AppDatabase, $GovNodesTable, GovNode>),
    GovNode,
    PrefetchHooks Function()> {
  $$GovNodesTableTableManager(_$AppDatabase db, $GovNodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GovNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GovNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GovNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> governmentId = const Value.absent(),
            Value<String> externalId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> shortName = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> nodeType = const Value.absent(),
            Value<bool> isHeadOfState = const Value.absent(),
            Value<bool> isHeadOfGovt = const Value.absent(),
            Value<bool?> isElected = const Value.absent(),
            Value<double?> mapX = const Value.absent(),
            Value<double?> mapY = const Value.absent(),
            Value<double?> mapWidth = const Value.absent(),
            Value<double?> mapHeight = const Value.absent(),
            Value<String> mapShape = const Value.absent(),
            Value<String?> mapIcon = const Value.absent(),
            Value<String?> mapColor = const Value.absent(),
            Value<String> mapLabelPos = const Value.absent(),
            Value<int> tierOrder = const Value.absent(),
            Value<String> unlockRequires = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GovNodesCompanion(
            id: id,
            governmentId: governmentId,
            externalId: externalId,
            name: name,
            shortName: shortName,
            description: description,
            nodeType: nodeType,
            isHeadOfState: isHeadOfState,
            isHeadOfGovt: isHeadOfGovt,
            isElected: isElected,
            mapX: mapX,
            mapY: mapY,
            mapWidth: mapWidth,
            mapHeight: mapHeight,
            mapShape: mapShape,
            mapIcon: mapIcon,
            mapColor: mapColor,
            mapLabelPos: mapLabelPos,
            tierOrder: tierOrder,
            unlockRequires: unlockRequires,
            isActive: isActive,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String governmentId,
            required String externalId,
            required String name,
            Value<String?> shortName = const Value.absent(),
            Value<String?> description = const Value.absent(),
            required String nodeType,
            Value<bool> isHeadOfState = const Value.absent(),
            Value<bool> isHeadOfGovt = const Value.absent(),
            Value<bool?> isElected = const Value.absent(),
            Value<double?> mapX = const Value.absent(),
            Value<double?> mapY = const Value.absent(),
            Value<double?> mapWidth = const Value.absent(),
            Value<double?> mapHeight = const Value.absent(),
            Value<String> mapShape = const Value.absent(),
            Value<String?> mapIcon = const Value.absent(),
            Value<String?> mapColor = const Value.absent(),
            Value<String> mapLabelPos = const Value.absent(),
            required int tierOrder,
            Value<String> unlockRequires = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GovNodesCompanion.insert(
            id: id,
            governmentId: governmentId,
            externalId: externalId,
            name: name,
            shortName: shortName,
            description: description,
            nodeType: nodeType,
            isHeadOfState: isHeadOfState,
            isHeadOfGovt: isHeadOfGovt,
            isElected: isElected,
            mapX: mapX,
            mapY: mapY,
            mapWidth: mapWidth,
            mapHeight: mapHeight,
            mapShape: mapShape,
            mapIcon: mapIcon,
            mapColor: mapColor,
            mapLabelPos: mapLabelPos,
            tierOrder: tierOrder,
            unlockRequires: unlockRequires,
            isActive: isActive,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GovNodesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GovNodesTable,
    GovNode,
    $$GovNodesTableFilterComposer,
    $$GovNodesTableOrderingComposer,
    $$GovNodesTableAnnotationComposer,
    $$GovNodesTableCreateCompanionBuilder,
    $$GovNodesTableUpdateCompanionBuilder,
    (GovNode, BaseReferences<_$AppDatabase, $GovNodesTable, GovNode>),
    GovNode,
    PrefetchHooks Function()>;
typedef $$GovEdgesTableCreateCompanionBuilder = GovEdgesCompanion Function({
  required String id,
  required String governmentId,
  required String fromNodeId,
  required String toNodeId,
  required String relationshipType,
  Value<String?> description,
  Value<bool> isVisibleOnMap,
  Value<String> lineStyle,
  Value<String?> lineColor,
  Value<String> arrowDirection,
  Value<int> rowid,
});
typedef $$GovEdgesTableUpdateCompanionBuilder = GovEdgesCompanion Function({
  Value<String> id,
  Value<String> governmentId,
  Value<String> fromNodeId,
  Value<String> toNodeId,
  Value<String> relationshipType,
  Value<String?> description,
  Value<bool> isVisibleOnMap,
  Value<String> lineStyle,
  Value<String?> lineColor,
  Value<String> arrowDirection,
  Value<int> rowid,
});

class $$GovEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $GovEdgesTable> {
  $$GovEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromNodeId => $composableBuilder(
      column: $table.fromNodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toNodeId => $composableBuilder(
      column: $table.toNodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVisibleOnMap => $composableBuilder(
      column: $table.isVisibleOnMap,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineStyle => $composableBuilder(
      column: $table.lineStyle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineColor => $composableBuilder(
      column: $table.lineColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get arrowDirection => $composableBuilder(
      column: $table.arrowDirection,
      builder: (column) => ColumnFilters(column));
}

class $$GovEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $GovEdgesTable> {
  $$GovEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get governmentId => $composableBuilder(
      column: $table.governmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromNodeId => $composableBuilder(
      column: $table.fromNodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toNodeId => $composableBuilder(
      column: $table.toNodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVisibleOnMap => $composableBuilder(
      column: $table.isVisibleOnMap,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineStyle => $composableBuilder(
      column: $table.lineStyle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineColor => $composableBuilder(
      column: $table.lineColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get arrowDirection => $composableBuilder(
      column: $table.arrowDirection,
      builder: (column) => ColumnOrderings(column));
}

class $$GovEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GovEdgesTable> {
  $$GovEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => column);

  GeneratedColumn<String> get fromNodeId => $composableBuilder(
      column: $table.fromNodeId, builder: (column) => column);

  GeneratedColumn<String> get toNodeId =>
      $composableBuilder(column: $table.toNodeId, builder: (column) => column);

  GeneratedColumn<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isVisibleOnMap => $composableBuilder(
      column: $table.isVisibleOnMap, builder: (column) => column);

  GeneratedColumn<String> get lineStyle =>
      $composableBuilder(column: $table.lineStyle, builder: (column) => column);

  GeneratedColumn<String> get lineColor =>
      $composableBuilder(column: $table.lineColor, builder: (column) => column);

  GeneratedColumn<String> get arrowDirection => $composableBuilder(
      column: $table.arrowDirection, builder: (column) => column);
}

class $$GovEdgesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GovEdgesTable,
    GovEdge,
    $$GovEdgesTableFilterComposer,
    $$GovEdgesTableOrderingComposer,
    $$GovEdgesTableAnnotationComposer,
    $$GovEdgesTableCreateCompanionBuilder,
    $$GovEdgesTableUpdateCompanionBuilder,
    (GovEdge, BaseReferences<_$AppDatabase, $GovEdgesTable, GovEdge>),
    GovEdge,
    PrefetchHooks Function()> {
  $$GovEdgesTableTableManager(_$AppDatabase db, $GovEdgesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GovEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GovEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GovEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> governmentId = const Value.absent(),
            Value<String> fromNodeId = const Value.absent(),
            Value<String> toNodeId = const Value.absent(),
            Value<String> relationshipType = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isVisibleOnMap = const Value.absent(),
            Value<String> lineStyle = const Value.absent(),
            Value<String?> lineColor = const Value.absent(),
            Value<String> arrowDirection = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GovEdgesCompanion(
            id: id,
            governmentId: governmentId,
            fromNodeId: fromNodeId,
            toNodeId: toNodeId,
            relationshipType: relationshipType,
            description: description,
            isVisibleOnMap: isVisibleOnMap,
            lineStyle: lineStyle,
            lineColor: lineColor,
            arrowDirection: arrowDirection,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String governmentId,
            required String fromNodeId,
            required String toNodeId,
            required String relationshipType,
            Value<String?> description = const Value.absent(),
            Value<bool> isVisibleOnMap = const Value.absent(),
            Value<String> lineStyle = const Value.absent(),
            Value<String?> lineColor = const Value.absent(),
            Value<String> arrowDirection = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GovEdgesCompanion.insert(
            id: id,
            governmentId: governmentId,
            fromNodeId: fromNodeId,
            toNodeId: toNodeId,
            relationshipType: relationshipType,
            description: description,
            isVisibleOnMap: isVisibleOnMap,
            lineStyle: lineStyle,
            lineColor: lineColor,
            arrowDirection: arrowDirection,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GovEdgesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GovEdgesTable,
    GovEdge,
    $$GovEdgesTableFilterComposer,
    $$GovEdgesTableOrderingComposer,
    $$GovEdgesTableAnnotationComposer,
    $$GovEdgesTableCreateCompanionBuilder,
    $$GovEdgesTableUpdateCompanionBuilder,
    (GovEdge, BaseReferences<_$AppDatabase, $GovEdgesTable, GovEdge>),
    GovEdge,
    PrefetchHooks Function()>;
typedef $$LocalDecksTableCreateCompanionBuilder = LocalDecksCompanion Function({
  required String id,
  Value<String?> nodeId,
  Value<String?> governmentId,
  required String externalId,
  required String name,
  Value<String?> description,
  Value<int> tierOrder,
  Value<bool> isPremium,
  Value<String> status,
  Value<int> cardCount,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$LocalDecksTableUpdateCompanionBuilder = LocalDecksCompanion Function({
  Value<String> id,
  Value<String?> nodeId,
  Value<String?> governmentId,
  Value<String> externalId,
  Value<String> name,
  Value<String?> description,
  Value<int> tierOrder,
  Value<bool> isPremium,
  Value<String> status,
  Value<int> cardCount,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$LocalDecksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDecksTable> {
  $$LocalDecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tierOrder => $composableBuilder(
      column: $table.tierOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPremium => $composableBuilder(
      column: $table.isPremium, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cardCount => $composableBuilder(
      column: $table.cardCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalDecksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDecksTable> {
  $$LocalDecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get governmentId => $composableBuilder(
      column: $table.governmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tierOrder => $composableBuilder(
      column: $table.tierOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPremium => $composableBuilder(
      column: $table.isPremium, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cardCount => $composableBuilder(
      column: $table.cardCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalDecksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDecksTable> {
  $$LocalDecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get tierOrder =>
      $composableBuilder(column: $table.tierOrder, builder: (column) => column);

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get cardCount =>
      $composableBuilder(column: $table.cardCount, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalDecksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalDecksTable,
    LocalDeck,
    $$LocalDecksTableFilterComposer,
    $$LocalDecksTableOrderingComposer,
    $$LocalDecksTableAnnotationComposer,
    $$LocalDecksTableCreateCompanionBuilder,
    $$LocalDecksTableUpdateCompanionBuilder,
    (LocalDeck, BaseReferences<_$AppDatabase, $LocalDecksTable, LocalDeck>),
    LocalDeck,
    PrefetchHooks Function()> {
  $$LocalDecksTableTableManager(_$AppDatabase db, $LocalDecksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> nodeId = const Value.absent(),
            Value<String?> governmentId = const Value.absent(),
            Value<String> externalId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> tierOrder = const Value.absent(),
            Value<bool> isPremium = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> cardCount = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDecksCompanion(
            id: id,
            nodeId: nodeId,
            governmentId: governmentId,
            externalId: externalId,
            name: name,
            description: description,
            tierOrder: tierOrder,
            isPremium: isPremium,
            status: status,
            cardCount: cardCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> nodeId = const Value.absent(),
            Value<String?> governmentId = const Value.absent(),
            required String externalId,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<int> tierOrder = const Value.absent(),
            Value<bool> isPremium = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> cardCount = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDecksCompanion.insert(
            id: id,
            nodeId: nodeId,
            governmentId: governmentId,
            externalId: externalId,
            name: name,
            description: description,
            tierOrder: tierOrder,
            isPremium: isPremium,
            status: status,
            cardCount: cardCount,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalDecksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalDecksTable,
    LocalDeck,
    $$LocalDecksTableFilterComposer,
    $$LocalDecksTableOrderingComposer,
    $$LocalDecksTableAnnotationComposer,
    $$LocalDecksTableCreateCompanionBuilder,
    $$LocalDecksTableUpdateCompanionBuilder,
    (LocalDeck, BaseReferences<_$AppDatabase, $LocalDecksTable, LocalDeck>),
    LocalDeck,
    PrefetchHooks Function()>;
typedef $$LocalCardsTableCreateCompanionBuilder = LocalCardsCompanion Function({
  required String id,
  required String deckId,
  required String externalId,
  required String politicianName,
  Value<String?> photoUrl,
  Value<String?> lqipBase64,
  required String title,
  Value<String?> party,
  Value<String?> jurisdiction,
  Value<String?> oneLiner,
  required String sourceUrl,
  Value<String?> gender,
  Value<String> cardType,
  Value<String?> body,
  Value<String?> recallPrompt,
  Value<String> tags,
  Value<bool> isActive,
  Value<int> sortOrder,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$LocalCardsTableUpdateCompanionBuilder = LocalCardsCompanion Function({
  Value<String> id,
  Value<String> deckId,
  Value<String> externalId,
  Value<String> politicianName,
  Value<String?> photoUrl,
  Value<String?> lqipBase64,
  Value<String> title,
  Value<String?> party,
  Value<String?> jurisdiction,
  Value<String?> oneLiner,
  Value<String> sourceUrl,
  Value<String?> gender,
  Value<String> cardType,
  Value<String?> body,
  Value<String?> recallPrompt,
  Value<String> tags,
  Value<bool> isActive,
  Value<int> sortOrder,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$LocalCardsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCardsTable> {
  $$LocalCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deckId => $composableBuilder(
      column: $table.deckId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get politicianName => $composableBuilder(
      column: $table.politicianName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lqipBase64 => $composableBuilder(
      column: $table.lqipBase64, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get party => $composableBuilder(
      column: $table.party, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jurisdiction => $composableBuilder(
      column: $table.jurisdiction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get oneLiner => $composableBuilder(
      column: $table.oneLiner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardType => $composableBuilder(
      column: $table.cardType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recallPrompt => $composableBuilder(
      column: $table.recallPrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCardsTable> {
  $$LocalCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deckId => $composableBuilder(
      column: $table.deckId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get politicianName => $composableBuilder(
      column: $table.politicianName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lqipBase64 => $composableBuilder(
      column: $table.lqipBase64, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get party => $composableBuilder(
      column: $table.party, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jurisdiction => $composableBuilder(
      column: $table.jurisdiction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get oneLiner => $composableBuilder(
      column: $table.oneLiner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardType => $composableBuilder(
      column: $table.cardType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recallPrompt => $composableBuilder(
      column: $table.recallPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCardsTable> {
  $$LocalCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
      column: $table.externalId, builder: (column) => column);

  GeneratedColumn<String> get politicianName => $composableBuilder(
      column: $table.politicianName, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get lqipBase64 => $composableBuilder(
      column: $table.lqipBase64, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get party =>
      $composableBuilder(column: $table.party, builder: (column) => column);

  GeneratedColumn<String> get jurisdiction => $composableBuilder(
      column: $table.jurisdiction, builder: (column) => column);

  GeneratedColumn<String> get oneLiner =>
      $composableBuilder(column: $table.oneLiner, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get recallPrompt => $composableBuilder(
      column: $table.recallPrompt, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalCardsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCardsTable,
    LocalCard,
    $$LocalCardsTableFilterComposer,
    $$LocalCardsTableOrderingComposer,
    $$LocalCardsTableAnnotationComposer,
    $$LocalCardsTableCreateCompanionBuilder,
    $$LocalCardsTableUpdateCompanionBuilder,
    (LocalCard, BaseReferences<_$AppDatabase, $LocalCardsTable, LocalCard>),
    LocalCard,
    PrefetchHooks Function()> {
  $$LocalCardsTableTableManager(_$AppDatabase db, $LocalCardsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> deckId = const Value.absent(),
            Value<String> externalId = const Value.absent(),
            Value<String> politicianName = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            Value<String?> lqipBase64 = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> party = const Value.absent(),
            Value<String?> jurisdiction = const Value.absent(),
            Value<String?> oneLiner = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<String> cardType = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> recallPrompt = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCardsCompanion(
            id: id,
            deckId: deckId,
            externalId: externalId,
            politicianName: politicianName,
            photoUrl: photoUrl,
            lqipBase64: lqipBase64,
            title: title,
            party: party,
            jurisdiction: jurisdiction,
            oneLiner: oneLiner,
            sourceUrl: sourceUrl,
            gender: gender,
            cardType: cardType,
            body: body,
            recallPrompt: recallPrompt,
            tags: tags,
            isActive: isActive,
            sortOrder: sortOrder,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String deckId,
            required String externalId,
            required String politicianName,
            Value<String?> photoUrl = const Value.absent(),
            Value<String?> lqipBase64 = const Value.absent(),
            required String title,
            Value<String?> party = const Value.absent(),
            Value<String?> jurisdiction = const Value.absent(),
            Value<String?> oneLiner = const Value.absent(),
            required String sourceUrl,
            Value<String?> gender = const Value.absent(),
            Value<String> cardType = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> recallPrompt = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCardsCompanion.insert(
            id: id,
            deckId: deckId,
            externalId: externalId,
            politicianName: politicianName,
            photoUrl: photoUrl,
            lqipBase64: lqipBase64,
            title: title,
            party: party,
            jurisdiction: jurisdiction,
            oneLiner: oneLiner,
            sourceUrl: sourceUrl,
            gender: gender,
            cardType: cardType,
            body: body,
            recallPrompt: recallPrompt,
            tags: tags,
            isActive: isActive,
            sortOrder: sortOrder,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCardsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalCardsTable,
    LocalCard,
    $$LocalCardsTableFilterComposer,
    $$LocalCardsTableOrderingComposer,
    $$LocalCardsTableAnnotationComposer,
    $$LocalCardsTableCreateCompanionBuilder,
    $$LocalCardsTableUpdateCompanionBuilder,
    (LocalCard, BaseReferences<_$AppDatabase, $LocalCardsTable, LocalCard>),
    LocalCard,
    PrefetchHooks Function()>;
typedef $$CardMemoryStatesTableCreateCompanionBuilder
    = CardMemoryStatesCompanion Function({
  required String cardId,
  Value<String> userId,
  Value<double> difficulty,
  Value<double> stability,
  Value<double> retrievability,
  Value<int> lastReviewedAt,
  Value<int> nextReviewAt,
  Value<int> intervalDays,
  Value<int> lapses,
  Value<int> reviewCount,
  Value<bool> isNew,
  Value<int> practiceCountSinceReview,
  Value<int> lastGrade,
  Value<int> rowid,
});
typedef $$CardMemoryStatesTableUpdateCompanionBuilder
    = CardMemoryStatesCompanion Function({
  Value<String> cardId,
  Value<String> userId,
  Value<double> difficulty,
  Value<double> stability,
  Value<double> retrievability,
  Value<int> lastReviewedAt,
  Value<int> nextReviewAt,
  Value<int> intervalDays,
  Value<int> lapses,
  Value<int> reviewCount,
  Value<bool> isNew,
  Value<int> practiceCountSinceReview,
  Value<int> lastGrade,
  Value<int> rowid,
});

class $$CardMemoryStatesTableFilterComposer
    extends Composer<_$AppDatabase, $CardMemoryStatesTable> {
  $$CardMemoryStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get retrievability => $composableBuilder(
      column: $table.retrievability,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReviewedAt => $composableBuilder(
      column: $table.lastReviewedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lapses => $composableBuilder(
      column: $table.lapses, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isNew => $composableBuilder(
      column: $table.isNew, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get practiceCountSinceReview => $composableBuilder(
      column: $table.practiceCountSinceReview,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastGrade => $composableBuilder(
      column: $table.lastGrade, builder: (column) => ColumnFilters(column));
}

class $$CardMemoryStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CardMemoryStatesTable> {
  $$CardMemoryStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get retrievability => $composableBuilder(
      column: $table.retrievability,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReviewedAt => $composableBuilder(
      column: $table.lastReviewedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lapses => $composableBuilder(
      column: $table.lapses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isNew => $composableBuilder(
      column: $table.isNew, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get practiceCountSinceReview => $composableBuilder(
      column: $table.practiceCountSinceReview,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastGrade => $composableBuilder(
      column: $table.lastGrade, builder: (column) => ColumnOrderings(column));
}

class $$CardMemoryStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardMemoryStatesTable> {
  $$CardMemoryStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get retrievability => $composableBuilder(
      column: $table.retrievability, builder: (column) => column);

  GeneratedColumn<int> get lastReviewedAt => $composableBuilder(
      column: $table.lastReviewedAt, builder: (column) => column);

  GeneratedColumn<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => column);

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<int> get practiceCountSinceReview => $composableBuilder(
      column: $table.practiceCountSinceReview, builder: (column) => column);

  GeneratedColumn<int> get lastGrade =>
      $composableBuilder(column: $table.lastGrade, builder: (column) => column);
}

class $$CardMemoryStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CardMemoryStatesTable,
    CardMemoryState,
    $$CardMemoryStatesTableFilterComposer,
    $$CardMemoryStatesTableOrderingComposer,
    $$CardMemoryStatesTableAnnotationComposer,
    $$CardMemoryStatesTableCreateCompanionBuilder,
    $$CardMemoryStatesTableUpdateCompanionBuilder,
    (
      CardMemoryState,
      BaseReferences<_$AppDatabase, $CardMemoryStatesTable, CardMemoryState>
    ),
    CardMemoryState,
    PrefetchHooks Function()> {
  $$CardMemoryStatesTableTableManager(
      _$AppDatabase db, $CardMemoryStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardMemoryStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardMemoryStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardMemoryStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cardId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<double> difficulty = const Value.absent(),
            Value<double> stability = const Value.absent(),
            Value<double> retrievability = const Value.absent(),
            Value<int> lastReviewedAt = const Value.absent(),
            Value<int> nextReviewAt = const Value.absent(),
            Value<int> intervalDays = const Value.absent(),
            Value<int> lapses = const Value.absent(),
            Value<int> reviewCount = const Value.absent(),
            Value<bool> isNew = const Value.absent(),
            Value<int> practiceCountSinceReview = const Value.absent(),
            Value<int> lastGrade = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CardMemoryStatesCompanion(
            cardId: cardId,
            userId: userId,
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt,
            intervalDays: intervalDays,
            lapses: lapses,
            reviewCount: reviewCount,
            isNew: isNew,
            practiceCountSinceReview: practiceCountSinceReview,
            lastGrade: lastGrade,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cardId,
            Value<String> userId = const Value.absent(),
            Value<double> difficulty = const Value.absent(),
            Value<double> stability = const Value.absent(),
            Value<double> retrievability = const Value.absent(),
            Value<int> lastReviewedAt = const Value.absent(),
            Value<int> nextReviewAt = const Value.absent(),
            Value<int> intervalDays = const Value.absent(),
            Value<int> lapses = const Value.absent(),
            Value<int> reviewCount = const Value.absent(),
            Value<bool> isNew = const Value.absent(),
            Value<int> practiceCountSinceReview = const Value.absent(),
            Value<int> lastGrade = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CardMemoryStatesCompanion.insert(
            cardId: cardId,
            userId: userId,
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt,
            intervalDays: intervalDays,
            lapses: lapses,
            reviewCount: reviewCount,
            isNew: isNew,
            practiceCountSinceReview: practiceCountSinceReview,
            lastGrade: lastGrade,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CardMemoryStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CardMemoryStatesTable,
    CardMemoryState,
    $$CardMemoryStatesTableFilterComposer,
    $$CardMemoryStatesTableOrderingComposer,
    $$CardMemoryStatesTableAnnotationComposer,
    $$CardMemoryStatesTableCreateCompanionBuilder,
    $$CardMemoryStatesTableUpdateCompanionBuilder,
    (
      CardMemoryState,
      BaseReferences<_$AppDatabase, $CardMemoryStatesTable, CardMemoryState>
    ),
    CardMemoryState,
    PrefetchHooks Function()>;
typedef $$ReviewLogsTableCreateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  Value<String> userId,
  required String cardId,
  required int reviewedAt,
  required int grade,
  required double stability,
  required double difficulty,
  required double retrievability,
  required int intervalDays,
  Value<bool> synced,
});
typedef $$ReviewLogsTableUpdateCompanionBuilder = ReviewLogsCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> cardId,
  Value<int> reviewedAt,
  Value<int> grade,
  Value<double> stability,
  Value<double> difficulty,
  Value<double> retrievability,
  Value<int> intervalDays,
  Value<bool> synced,
});

class $$ReviewLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get retrievability => $composableBuilder(
      column: $table.retrievability,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$ReviewLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stability => $composableBuilder(
      column: $table.stability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get retrievability => $composableBuilder(
      column: $table.retrievability,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$ReviewLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<int> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<double> get retrievability => $composableBuilder(
      column: $table.retrievability, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ReviewLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReviewLogsTable,
    ReviewLog,
    $$ReviewLogsTableFilterComposer,
    $$ReviewLogsTableOrderingComposer,
    $$ReviewLogsTableAnnotationComposer,
    $$ReviewLogsTableCreateCompanionBuilder,
    $$ReviewLogsTableUpdateCompanionBuilder,
    (ReviewLog, BaseReferences<_$AppDatabase, $ReviewLogsTable, ReviewLog>),
    ReviewLog,
    PrefetchHooks Function()> {
  $$ReviewLogsTableTableManager(_$AppDatabase db, $ReviewLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> cardId = const Value.absent(),
            Value<int> reviewedAt = const Value.absent(),
            Value<int> grade = const Value.absent(),
            Value<double> stability = const Value.absent(),
            Value<double> difficulty = const Value.absent(),
            Value<double> retrievability = const Value.absent(),
            Value<int> intervalDays = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              ReviewLogsCompanion(
            id: id,
            userId: userId,
            cardId: cardId,
            reviewedAt: reviewedAt,
            grade: grade,
            stability: stability,
            difficulty: difficulty,
            retrievability: retrievability,
            intervalDays: intervalDays,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            required String cardId,
            required int reviewedAt,
            required int grade,
            required double stability,
            required double difficulty,
            required double retrievability,
            required int intervalDays,
            Value<bool> synced = const Value.absent(),
          }) =>
              ReviewLogsCompanion.insert(
            id: id,
            userId: userId,
            cardId: cardId,
            reviewedAt: reviewedAt,
            grade: grade,
            stability: stability,
            difficulty: difficulty,
            retrievability: retrievability,
            intervalDays: intervalDays,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReviewLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReviewLogsTable,
    ReviewLog,
    $$ReviewLogsTableFilterComposer,
    $$ReviewLogsTableOrderingComposer,
    $$ReviewLogsTableAnnotationComposer,
    $$ReviewLogsTableCreateCompanionBuilder,
    $$ReviewLogsTableUpdateCompanionBuilder,
    (ReviewLog, BaseReferences<_$AppDatabase, $ReviewLogsTable, ReviewLog>),
    ReviewLog,
    PrefetchHooks Function()>;
typedef $$UserNodeProgressTableCreateCompanionBuilder
    = UserNodeProgressCompanion Function({
  required String nodeId,
  Value<String> userId,
  required String governmentId,
  Value<String> status,
  Value<int?> unlockedAt,
  Value<int?> completedAt,
  Value<int> rowid,
});
typedef $$UserNodeProgressTableUpdateCompanionBuilder
    = UserNodeProgressCompanion Function({
  Value<String> nodeId,
  Value<String> userId,
  Value<String> governmentId,
  Value<String> status,
  Value<int?> unlockedAt,
  Value<int?> completedAt,
  Value<int> rowid,
});

class $$UserNodeProgressTableFilterComposer
    extends Composer<_$AppDatabase, $UserNodeProgressTable> {
  $$UserNodeProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$UserNodeProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $UserNodeProgressTable> {
  $$UserNodeProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get governmentId => $composableBuilder(
      column: $table.governmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserNodeProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserNodeProgressTable> {
  $$UserNodeProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get governmentId => $composableBuilder(
      column: $table.governmentId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$UserNodeProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserNodeProgressTable,
    UserNodeProgressEntry,
    $$UserNodeProgressTableFilterComposer,
    $$UserNodeProgressTableOrderingComposer,
    $$UserNodeProgressTableAnnotationComposer,
    $$UserNodeProgressTableCreateCompanionBuilder,
    $$UserNodeProgressTableUpdateCompanionBuilder,
    (
      UserNodeProgressEntry,
      BaseReferences<_$AppDatabase, $UserNodeProgressTable,
          UserNodeProgressEntry>
    ),
    UserNodeProgressEntry,
    PrefetchHooks Function()> {
  $$UserNodeProgressTableTableManager(
      _$AppDatabase db, $UserNodeProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserNodeProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserNodeProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserNodeProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> nodeId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> governmentId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> unlockedAt = const Value.absent(),
            Value<int?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserNodeProgressCompanion(
            nodeId: nodeId,
            userId: userId,
            governmentId: governmentId,
            status: status,
            unlockedAt: unlockedAt,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String nodeId,
            Value<String> userId = const Value.absent(),
            required String governmentId,
            Value<String> status = const Value.absent(),
            Value<int?> unlockedAt = const Value.absent(),
            Value<int?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserNodeProgressCompanion.insert(
            nodeId: nodeId,
            userId: userId,
            governmentId: governmentId,
            status: status,
            unlockedAt: unlockedAt,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserNodeProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserNodeProgressTable,
    UserNodeProgressEntry,
    $$UserNodeProgressTableFilterComposer,
    $$UserNodeProgressTableOrderingComposer,
    $$UserNodeProgressTableAnnotationComposer,
    $$UserNodeProgressTableCreateCompanionBuilder,
    $$UserNodeProgressTableUpdateCompanionBuilder,
    (
      UserNodeProgressEntry,
      BaseReferences<_$AppDatabase, $UserNodeProgressTable,
          UserNodeProgressEntry>
    ),
    UserNodeProgressEntry,
    PrefetchHooks Function()>;
typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  Value<String> userId,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> userId,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppMetaTable,
    AppMetaData,
    $$AppMetaTableFilterComposer,
    $$AppMetaTableOrderingComposer,
    $$AppMetaTableAnnotationComposer,
    $$AppMetaTableCreateCompanionBuilder,
    $$AppMetaTableUpdateCompanionBuilder,
    (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
    AppMetaData,
    PrefetchHooks Function()> {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetaCompanion(
            key: key,
            userId: userId,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            Value<String> userId = const Value.absent(),
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetaCompanion.insert(
            key: key,
            userId: userId,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppMetaTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppMetaTable,
    AppMetaData,
    $$AppMetaTableFilterComposer,
    $$AppMetaTableOrderingComposer,
    $$AppMetaTableAnnotationComposer,
    $$AppMetaTableCreateCompanionBuilder,
    $$AppMetaTableUpdateCompanionBuilder,
    (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
    AppMetaData,
    PrefetchHooks Function()>;
typedef $$ChapterProgressTableCreateCompanionBuilder = ChapterProgressCompanion
    Function({
  Value<String> userId,
  required String seasonId,
  required String chapterId,
  Value<int> dayInChapter,
  Value<int> roundsCompleted,
  required int startedAt,
  Value<int?> completedAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$ChapterProgressTableUpdateCompanionBuilder = ChapterProgressCompanion
    Function({
  Value<String> userId,
  Value<String> seasonId,
  Value<String> chapterId,
  Value<int> dayInChapter,
  Value<int> roundsCompleted,
  Value<int> startedAt,
  Value<int?> completedAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$ChapterProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterProgressTable> {
  $$ChapterProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seasonId => $composableBuilder(
      column: $table.seasonId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get roundsCompleted => $composableBuilder(
      column: $table.roundsCompleted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ChapterProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterProgressTable> {
  $$ChapterProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seasonId => $composableBuilder(
      column: $table.seasonId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get roundsCompleted => $composableBuilder(
      column: $table.roundsCompleted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChapterProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterProgressTable> {
  $$ChapterProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get seasonId =>
      $composableBuilder(column: $table.seasonId, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter, builder: (column) => column);

  GeneratedColumn<int> get roundsCompleted => $composableBuilder(
      column: $table.roundsCompleted, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChapterProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChapterProgressTable,
    ChapterProgressEntry,
    $$ChapterProgressTableFilterComposer,
    $$ChapterProgressTableOrderingComposer,
    $$ChapterProgressTableAnnotationComposer,
    $$ChapterProgressTableCreateCompanionBuilder,
    $$ChapterProgressTableUpdateCompanionBuilder,
    (
      ChapterProgressEntry,
      BaseReferences<_$AppDatabase, $ChapterProgressTable, ChapterProgressEntry>
    ),
    ChapterProgressEntry,
    PrefetchHooks Function()> {
  $$ChapterProgressTableTableManager(
      _$AppDatabase db, $ChapterProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> seasonId = const Value.absent(),
            Value<String> chapterId = const Value.absent(),
            Value<int> dayInChapter = const Value.absent(),
            Value<int> roundsCompleted = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<int?> completedAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChapterProgressCompanion(
            userId: userId,
            seasonId: seasonId,
            chapterId: chapterId,
            dayInChapter: dayInChapter,
            roundsCompleted: roundsCompleted,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            required String seasonId,
            required String chapterId,
            Value<int> dayInChapter = const Value.absent(),
            Value<int> roundsCompleted = const Value.absent(),
            required int startedAt,
            Value<int?> completedAt = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ChapterProgressCompanion.insert(
            userId: userId,
            seasonId: seasonId,
            chapterId: chapterId,
            dayInChapter: dayInChapter,
            roundsCompleted: roundsCompleted,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChapterProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChapterProgressTable,
    ChapterProgressEntry,
    $$ChapterProgressTableFilterComposer,
    $$ChapterProgressTableOrderingComposer,
    $$ChapterProgressTableAnnotationComposer,
    $$ChapterProgressTableCreateCompanionBuilder,
    $$ChapterProgressTableUpdateCompanionBuilder,
    (
      ChapterProgressEntry,
      BaseReferences<_$AppDatabase, $ChapterProgressTable, ChapterProgressEntry>
    ),
    ChapterProgressEntry,
    PrefetchHooks Function()>;
typedef $$DailyRoundsTableCreateCompanionBuilder = DailyRoundsCompanion
    Function({
  Value<String> userId,
  required String dateIso,
  required String chapterId,
  required int dayInChapter,
  Value<String> cardIdsJson,
  Value<String> triviaJson,
  Value<String> gradesJson,
  Value<String> answersJson,
  Value<String> phase,
  required int startedAt,
  Value<int?> completedAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$DailyRoundsTableUpdateCompanionBuilder = DailyRoundsCompanion
    Function({
  Value<String> userId,
  Value<String> dateIso,
  Value<String> chapterId,
  Value<int> dayInChapter,
  Value<String> cardIdsJson,
  Value<String> triviaJson,
  Value<String> gradesJson,
  Value<String> answersJson,
  Value<String> phase,
  Value<int> startedAt,
  Value<int?> completedAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$DailyRoundsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyRoundsTable> {
  $$DailyRoundsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateIso => $composableBuilder(
      column: $table.dateIso, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardIdsJson => $composableBuilder(
      column: $table.cardIdsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get triviaJson => $composableBuilder(
      column: $table.triviaJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gradesJson => $composableBuilder(
      column: $table.gradesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answersJson => $composableBuilder(
      column: $table.answersJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DailyRoundsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyRoundsTable> {
  $$DailyRoundsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateIso => $composableBuilder(
      column: $table.dateIso, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardIdsJson => $composableBuilder(
      column: $table.cardIdsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get triviaJson => $composableBuilder(
      column: $table.triviaJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gradesJson => $composableBuilder(
      column: $table.gradesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answersJson => $composableBuilder(
      column: $table.answersJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phase => $composableBuilder(
      column: $table.phase, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DailyRoundsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyRoundsTable> {
  $$DailyRoundsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dateIso =>
      $composableBuilder(column: $table.dateIso, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get dayInChapter => $composableBuilder(
      column: $table.dayInChapter, builder: (column) => column);

  GeneratedColumn<String> get cardIdsJson => $composableBuilder(
      column: $table.cardIdsJson, builder: (column) => column);

  GeneratedColumn<String> get triviaJson => $composableBuilder(
      column: $table.triviaJson, builder: (column) => column);

  GeneratedColumn<String> get gradesJson => $composableBuilder(
      column: $table.gradesJson, builder: (column) => column);

  GeneratedColumn<String> get answersJson => $composableBuilder(
      column: $table.answersJson, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DailyRoundsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyRoundsTable,
    DailyRoundEntry,
    $$DailyRoundsTableFilterComposer,
    $$DailyRoundsTableOrderingComposer,
    $$DailyRoundsTableAnnotationComposer,
    $$DailyRoundsTableCreateCompanionBuilder,
    $$DailyRoundsTableUpdateCompanionBuilder,
    (
      DailyRoundEntry,
      BaseReferences<_$AppDatabase, $DailyRoundsTable, DailyRoundEntry>
    ),
    DailyRoundEntry,
    PrefetchHooks Function()> {
  $$DailyRoundsTableTableManager(_$AppDatabase db, $DailyRoundsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyRoundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyRoundsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyRoundsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> dateIso = const Value.absent(),
            Value<String> chapterId = const Value.absent(),
            Value<int> dayInChapter = const Value.absent(),
            Value<String> cardIdsJson = const Value.absent(),
            Value<String> triviaJson = const Value.absent(),
            Value<String> gradesJson = const Value.absent(),
            Value<String> answersJson = const Value.absent(),
            Value<String> phase = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<int?> completedAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyRoundsCompanion(
            userId: userId,
            dateIso: dateIso,
            chapterId: chapterId,
            dayInChapter: dayInChapter,
            cardIdsJson: cardIdsJson,
            triviaJson: triviaJson,
            gradesJson: gradesJson,
            answersJson: answersJson,
            phase: phase,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            required String dateIso,
            required String chapterId,
            required int dayInChapter,
            Value<String> cardIdsJson = const Value.absent(),
            Value<String> triviaJson = const Value.absent(),
            Value<String> gradesJson = const Value.absent(),
            Value<String> answersJson = const Value.absent(),
            Value<String> phase = const Value.absent(),
            required int startedAt,
            Value<int?> completedAt = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyRoundsCompanion.insert(
            userId: userId,
            dateIso: dateIso,
            chapterId: chapterId,
            dayInChapter: dayInChapter,
            cardIdsJson: cardIdsJson,
            triviaJson: triviaJson,
            gradesJson: gradesJson,
            answersJson: answersJson,
            phase: phase,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailyRoundsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailyRoundsTable,
    DailyRoundEntry,
    $$DailyRoundsTableFilterComposer,
    $$DailyRoundsTableOrderingComposer,
    $$DailyRoundsTableAnnotationComposer,
    $$DailyRoundsTableCreateCompanionBuilder,
    $$DailyRoundsTableUpdateCompanionBuilder,
    (
      DailyRoundEntry,
      BaseReferences<_$AppDatabase, $DailyRoundsTable, DailyRoundEntry>
    ),
    DailyRoundEntry,
    PrefetchHooks Function()>;
typedef $$PoliticianBiosTableCreateCompanionBuilder = PoliticianBiosCompanion
    Function({
  required String cardId,
  Value<String?> wikidataQid,
  Value<String?> wikipediaTitle,
  Value<String?> wikipediaUrl,
  Value<String?> bioExtract,
  Value<int?> fetchedAt,
  Value<int?> lastError,
  Value<String?> lastErrorMessage,
  Value<int> rowid,
});
typedef $$PoliticianBiosTableUpdateCompanionBuilder = PoliticianBiosCompanion
    Function({
  Value<String> cardId,
  Value<String?> wikidataQid,
  Value<String?> wikipediaTitle,
  Value<String?> wikipediaUrl,
  Value<String?> bioExtract,
  Value<int?> fetchedAt,
  Value<int?> lastError,
  Value<String?> lastErrorMessage,
  Value<int> rowid,
});

class $$PoliticianBiosTableFilterComposer
    extends Composer<_$AppDatabase, $PoliticianBiosTable> {
  $$PoliticianBiosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wikidataQid => $composableBuilder(
      column: $table.wikidataQid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wikipediaTitle => $composableBuilder(
      column: $table.wikipediaTitle,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wikipediaUrl => $composableBuilder(
      column: $table.wikipediaUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bioExtract => $composableBuilder(
      column: $table.bioExtract, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastErrorMessage => $composableBuilder(
      column: $table.lastErrorMessage,
      builder: (column) => ColumnFilters(column));
}

class $$PoliticianBiosTableOrderingComposer
    extends Composer<_$AppDatabase, $PoliticianBiosTable> {
  $$PoliticianBiosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wikidataQid => $composableBuilder(
      column: $table.wikidataQid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wikipediaTitle => $composableBuilder(
      column: $table.wikipediaTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wikipediaUrl => $composableBuilder(
      column: $table.wikipediaUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bioExtract => $composableBuilder(
      column: $table.bioExtract, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastErrorMessage => $composableBuilder(
      column: $table.lastErrorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$PoliticianBiosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoliticianBiosTable> {
  $$PoliticianBiosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get wikidataQid => $composableBuilder(
      column: $table.wikidataQid, builder: (column) => column);

  GeneratedColumn<String> get wikipediaTitle => $composableBuilder(
      column: $table.wikipediaTitle, builder: (column) => column);

  GeneratedColumn<String> get wikipediaUrl => $composableBuilder(
      column: $table.wikipediaUrl, builder: (column) => column);

  GeneratedColumn<String> get bioExtract => $composableBuilder(
      column: $table.bioExtract, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get lastErrorMessage => $composableBuilder(
      column: $table.lastErrorMessage, builder: (column) => column);
}

class $$PoliticianBiosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PoliticianBiosTable,
    PoliticianBio,
    $$PoliticianBiosTableFilterComposer,
    $$PoliticianBiosTableOrderingComposer,
    $$PoliticianBiosTableAnnotationComposer,
    $$PoliticianBiosTableCreateCompanionBuilder,
    $$PoliticianBiosTableUpdateCompanionBuilder,
    (
      PoliticianBio,
      BaseReferences<_$AppDatabase, $PoliticianBiosTable, PoliticianBio>
    ),
    PoliticianBio,
    PrefetchHooks Function()> {
  $$PoliticianBiosTableTableManager(
      _$AppDatabase db, $PoliticianBiosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoliticianBiosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoliticianBiosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoliticianBiosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cardId = const Value.absent(),
            Value<String?> wikidataQid = const Value.absent(),
            Value<String?> wikipediaTitle = const Value.absent(),
            Value<String?> wikipediaUrl = const Value.absent(),
            Value<String?> bioExtract = const Value.absent(),
            Value<int?> fetchedAt = const Value.absent(),
            Value<int?> lastError = const Value.absent(),
            Value<String?> lastErrorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PoliticianBiosCompanion(
            cardId: cardId,
            wikidataQid: wikidataQid,
            wikipediaTitle: wikipediaTitle,
            wikipediaUrl: wikipediaUrl,
            bioExtract: bioExtract,
            fetchedAt: fetchedAt,
            lastError: lastError,
            lastErrorMessage: lastErrorMessage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cardId,
            Value<String?> wikidataQid = const Value.absent(),
            Value<String?> wikipediaTitle = const Value.absent(),
            Value<String?> wikipediaUrl = const Value.absent(),
            Value<String?> bioExtract = const Value.absent(),
            Value<int?> fetchedAt = const Value.absent(),
            Value<int?> lastError = const Value.absent(),
            Value<String?> lastErrorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PoliticianBiosCompanion.insert(
            cardId: cardId,
            wikidataQid: wikidataQid,
            wikipediaTitle: wikipediaTitle,
            wikipediaUrl: wikipediaUrl,
            bioExtract: bioExtract,
            fetchedAt: fetchedAt,
            lastError: lastError,
            lastErrorMessage: lastErrorMessage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PoliticianBiosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PoliticianBiosTable,
    PoliticianBio,
    $$PoliticianBiosTableFilterComposer,
    $$PoliticianBiosTableOrderingComposer,
    $$PoliticianBiosTableAnnotationComposer,
    $$PoliticianBiosTableCreateCompanionBuilder,
    $$PoliticianBiosTableUpdateCompanionBuilder,
    (
      PoliticianBio,
      BaseReferences<_$AppDatabase, $PoliticianBiosTable, PoliticianBio>
    ),
    PoliticianBio,
    PrefetchHooks Function()>;
typedef $$CompletedRunsTableCreateCompanionBuilder = CompletedRunsCompanion
    Function({
  required String id,
  Value<String> userId,
  required String mode,
  required int completedAt,
  Value<int?> durationMs,
  Value<int?> score,
  Value<int?> correctCount,
  Value<int?> totalCount,
  Value<String?> summary,
  Value<String> payload,
  Value<int> rowid,
});
typedef $$CompletedRunsTableUpdateCompanionBuilder = CompletedRunsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> mode,
  Value<int> completedAt,
  Value<int?> durationMs,
  Value<int?> score,
  Value<int?> correctCount,
  Value<int?> totalCount,
  Value<String?> summary,
  Value<String> payload,
  Value<int> rowid,
});

class $$CompletedRunsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletedRunsTable> {
  $$CompletedRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$CompletedRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletedRunsTable> {
  $$CompletedRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get correctCount => $composableBuilder(
      column: $table.correctCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$CompletedRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletedRunsTable> {
  $$CompletedRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => column);

  GeneratedColumn<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$CompletedRunsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CompletedRunsTable,
    CompletedRunEntry,
    $$CompletedRunsTableFilterComposer,
    $$CompletedRunsTableOrderingComposer,
    $$CompletedRunsTableAnnotationComposer,
    $$CompletedRunsTableCreateCompanionBuilder,
    $$CompletedRunsTableUpdateCompanionBuilder,
    (
      CompletedRunEntry,
      BaseReferences<_$AppDatabase, $CompletedRunsTable, CompletedRunEntry>
    ),
    CompletedRunEntry,
    PrefetchHooks Function()> {
  $$CompletedRunsTableTableManager(_$AppDatabase db, $CompletedRunsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletedRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletedRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletedRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<int> completedAt = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<int?> score = const Value.absent(),
            Value<int?> correctCount = const Value.absent(),
            Value<int?> totalCount = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CompletedRunsCompanion(
            id: id,
            userId: userId,
            mode: mode,
            completedAt: completedAt,
            durationMs: durationMs,
            score: score,
            correctCount: correctCount,
            totalCount: totalCount,
            summary: summary,
            payload: payload,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> userId = const Value.absent(),
            required String mode,
            required int completedAt,
            Value<int?> durationMs = const Value.absent(),
            Value<int?> score = const Value.absent(),
            Value<int?> correctCount = const Value.absent(),
            Value<int?> totalCount = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CompletedRunsCompanion.insert(
            id: id,
            userId: userId,
            mode: mode,
            completedAt: completedAt,
            durationMs: durationMs,
            score: score,
            correctCount: correctCount,
            totalCount: totalCount,
            summary: summary,
            payload: payload,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CompletedRunsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CompletedRunsTable,
    CompletedRunEntry,
    $$CompletedRunsTableFilterComposer,
    $$CompletedRunsTableOrderingComposer,
    $$CompletedRunsTableAnnotationComposer,
    $$CompletedRunsTableCreateCompanionBuilder,
    $$CompletedRunsTableUpdateCompanionBuilder,
    (
      CompletedRunEntry,
      BaseReferences<_$AppDatabase, $CompletedRunsTable, CompletedRunEntry>
    ),
    CompletedRunEntry,
    PrefetchHooks Function()>;
typedef $$OutboxEventsTableCreateCompanionBuilder = OutboxEventsCompanion
    Function({
  required String eventId,
  required String type,
  Value<String?> questionId,
  Value<String?> attemptId,
  Value<String?> chosenKey,
  Value<String?> grade,
  Value<String> payload,
  required int clientTs,
  Value<int> tries,
  Value<String?> lastError,
  required int createdAt,
  Value<int> rowid,
});
typedef $$OutboxEventsTableUpdateCompanionBuilder = OutboxEventsCompanion
    Function({
  Value<String> eventId,
  Value<String> type,
  Value<String?> questionId,
  Value<String?> attemptId,
  Value<String?> chosenKey,
  Value<String?> grade,
  Value<String> payload,
  Value<int> clientTs,
  Value<int> tries,
  Value<String?> lastError,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$OutboxEventsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attemptId => $composableBuilder(
      column: $table.attemptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chosenKey => $composableBuilder(
      column: $table.chosenKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clientTs => $composableBuilder(
      column: $table.clientTs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tries => $composableBuilder(
      column: $table.tries, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attemptId => $composableBuilder(
      column: $table.attemptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chosenKey => $composableBuilder(
      column: $table.chosenKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clientTs => $composableBuilder(
      column: $table.clientTs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tries => $composableBuilder(
      column: $table.tries, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => column);

  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get chosenKey =>
      $composableBuilder(column: $table.chosenKey, builder: (column) => column);

  GeneratedColumn<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get clientTs =>
      $composableBuilder(column: $table.clientTs, builder: (column) => column);

  GeneratedColumn<int> get tries =>
      $composableBuilder(column: $table.tries, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxEventsTable,
    OutboxEvent,
    $$OutboxEventsTableFilterComposer,
    $$OutboxEventsTableOrderingComposer,
    $$OutboxEventsTableAnnotationComposer,
    $$OutboxEventsTableCreateCompanionBuilder,
    $$OutboxEventsTableUpdateCompanionBuilder,
    (
      OutboxEvent,
      BaseReferences<_$AppDatabase, $OutboxEventsTable, OutboxEvent>
    ),
    OutboxEvent,
    PrefetchHooks Function()> {
  $$OutboxEventsTableTableManager(_$AppDatabase db, $OutboxEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> eventId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> questionId = const Value.absent(),
            Value<String?> attemptId = const Value.absent(),
            Value<String?> chosenKey = const Value.absent(),
            Value<String?> grade = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> clientTs = const Value.absent(),
            Value<int> tries = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEventsCompanion(
            eventId: eventId,
            type: type,
            questionId: questionId,
            attemptId: attemptId,
            chosenKey: chosenKey,
            grade: grade,
            payload: payload,
            clientTs: clientTs,
            tries: tries,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String eventId,
            required String type,
            Value<String?> questionId = const Value.absent(),
            Value<String?> attemptId = const Value.absent(),
            Value<String?> chosenKey = const Value.absent(),
            Value<String?> grade = const Value.absent(),
            Value<String> payload = const Value.absent(),
            required int clientTs,
            Value<int> tries = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEventsCompanion.insert(
            eventId: eventId,
            type: type,
            questionId: questionId,
            attemptId: attemptId,
            chosenKey: chosenKey,
            grade: grade,
            payload: payload,
            clientTs: clientTs,
            tries: tries,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxEventsTable,
    OutboxEvent,
    $$OutboxEventsTableFilterComposer,
    $$OutboxEventsTableOrderingComposer,
    $$OutboxEventsTableAnnotationComposer,
    $$OutboxEventsTableCreateCompanionBuilder,
    $$OutboxEventsTableUpdateCompanionBuilder,
    (
      OutboxEvent,
      BaseReferences<_$AppDatabase, $OutboxEventsTable, OutboxEvent>
    ),
    OutboxEvent,
    PrefetchHooks Function()>;
typedef $$FcleAnswersTableCreateCompanionBuilder = FcleAnswersCompanion
    Function({
  Value<int> id,
  required String questionId,
  required String domain,
  required bool correct,
  Value<bool> inMock,
  required int answeredAt,
});
typedef $$FcleAnswersTableUpdateCompanionBuilder = FcleAnswersCompanion
    Function({
  Value<int> id,
  Value<String> questionId,
  Value<String> domain,
  Value<bool> correct,
  Value<bool> inMock,
  Value<int> answeredAt,
});

class $$FcleAnswersTableFilterComposer
    extends Composer<_$AppDatabase, $FcleAnswersTable> {
  $$FcleAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get domain => $composableBuilder(
      column: $table.domain, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get correct => $composableBuilder(
      column: $table.correct, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inMock => $composableBuilder(
      column: $table.inMock, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get answeredAt => $composableBuilder(
      column: $table.answeredAt, builder: (column) => ColumnFilters(column));
}

class $$FcleAnswersTableOrderingComposer
    extends Composer<_$AppDatabase, $FcleAnswersTable> {
  $$FcleAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get domain => $composableBuilder(
      column: $table.domain, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get correct => $composableBuilder(
      column: $table.correct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inMock => $composableBuilder(
      column: $table.inMock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get answeredAt => $composableBuilder(
      column: $table.answeredAt, builder: (column) => ColumnOrderings(column));
}

class $$FcleAnswersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FcleAnswersTable> {
  $$FcleAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
      column: $table.questionId, builder: (column) => column);

  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<bool> get inMock =>
      $composableBuilder(column: $table.inMock, builder: (column) => column);

  GeneratedColumn<int> get answeredAt => $composableBuilder(
      column: $table.answeredAt, builder: (column) => column);
}

class $$FcleAnswersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FcleAnswersTable,
    FcleAnswer,
    $$FcleAnswersTableFilterComposer,
    $$FcleAnswersTableOrderingComposer,
    $$FcleAnswersTableAnnotationComposer,
    $$FcleAnswersTableCreateCompanionBuilder,
    $$FcleAnswersTableUpdateCompanionBuilder,
    (FcleAnswer, BaseReferences<_$AppDatabase, $FcleAnswersTable, FcleAnswer>),
    FcleAnswer,
    PrefetchHooks Function()> {
  $$FcleAnswersTableTableManager(_$AppDatabase db, $FcleAnswersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FcleAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FcleAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FcleAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> questionId = const Value.absent(),
            Value<String> domain = const Value.absent(),
            Value<bool> correct = const Value.absent(),
            Value<bool> inMock = const Value.absent(),
            Value<int> answeredAt = const Value.absent(),
          }) =>
              FcleAnswersCompanion(
            id: id,
            questionId: questionId,
            domain: domain,
            correct: correct,
            inMock: inMock,
            answeredAt: answeredAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String questionId,
            required String domain,
            required bool correct,
            Value<bool> inMock = const Value.absent(),
            required int answeredAt,
          }) =>
              FcleAnswersCompanion.insert(
            id: id,
            questionId: questionId,
            domain: domain,
            correct: correct,
            inMock: inMock,
            answeredAt: answeredAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FcleAnswersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FcleAnswersTable,
    FcleAnswer,
    $$FcleAnswersTableFilterComposer,
    $$FcleAnswersTableOrderingComposer,
    $$FcleAnswersTableAnnotationComposer,
    $$FcleAnswersTableCreateCompanionBuilder,
    $$FcleAnswersTableUpdateCompanionBuilder,
    (FcleAnswer, BaseReferences<_$AppDatabase, $FcleAnswersTable, FcleAnswer>),
    FcleAnswer,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GovNodesTableTableManager get govNodes =>
      $$GovNodesTableTableManager(_db, _db.govNodes);
  $$GovEdgesTableTableManager get govEdges =>
      $$GovEdgesTableTableManager(_db, _db.govEdges);
  $$LocalDecksTableTableManager get localDecks =>
      $$LocalDecksTableTableManager(_db, _db.localDecks);
  $$LocalCardsTableTableManager get localCards =>
      $$LocalCardsTableTableManager(_db, _db.localCards);
  $$CardMemoryStatesTableTableManager get cardMemoryStates =>
      $$CardMemoryStatesTableTableManager(_db, _db.cardMemoryStates);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$UserNodeProgressTableTableManager get userNodeProgress =>
      $$UserNodeProgressTableTableManager(_db, _db.userNodeProgress);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$ChapterProgressTableTableManager get chapterProgress =>
      $$ChapterProgressTableTableManager(_db, _db.chapterProgress);
  $$DailyRoundsTableTableManager get dailyRounds =>
      $$DailyRoundsTableTableManager(_db, _db.dailyRounds);
  $$PoliticianBiosTableTableManager get politicianBios =>
      $$PoliticianBiosTableTableManager(_db, _db.politicianBios);
  $$CompletedRunsTableTableManager get completedRuns =>
      $$CompletedRunsTableTableManager(_db, _db.completedRuns);
  $$OutboxEventsTableTableManager get outboxEvents =>
      $$OutboxEventsTableTableManager(_db, _db.outboxEvents);
  $$FcleAnswersTableTableManager get fcleAnswers =>
      $$FcleAnswersTableTableManager(_db, _db.fcleAnswers);
}
