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
      defaultValue: const Constant(5.0));
  static const VerificationMeta _stabilityMeta =
      const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
      'stability', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _retrievabilityMeta =
      const VerificationMeta('retrievability');
  @override
  late final GeneratedColumn<double> retrievability = GeneratedColumn<double>(
      'retrievability', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
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

class $DailyChallengeCachesTable extends DailyChallengeCaches
    with TableInfo<$DailyChallengeCachesTable, DailyChallengeCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyChallengeCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _challengeDateMeta =
      const VerificationMeta('challengeDate');
  @override
  late final GeneratedColumn<String> challengeDate = GeneratedColumn<String>(
      'challenge_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cardIdsMeta =
      const VerificationMeta('cardIds');
  @override
  late final GeneratedColumn<String> cardIds = GeneratedColumn<String>(
      'card_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shareTemplateMeta =
      const VerificationMeta('shareTemplate');
  @override
  late final GeneratedColumn<String> shareTemplate = GeneratedColumn<String>(
      'share_template', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [challengeDate, cardIds, shareTemplate, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_challenge_caches';
  @override
  VerificationContext validateIntegrity(
      Insertable<DailyChallengeCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('challenge_date')) {
      context.handle(
          _challengeDateMeta,
          challengeDate.isAcceptableOrUnknown(
              data['challenge_date']!, _challengeDateMeta));
    } else if (isInserting) {
      context.missing(_challengeDateMeta);
    }
    if (data.containsKey('card_ids')) {
      context.handle(_cardIdsMeta,
          cardIds.isAcceptableOrUnknown(data['card_ids']!, _cardIdsMeta));
    } else if (isInserting) {
      context.missing(_cardIdsMeta);
    }
    if (data.containsKey('share_template')) {
      context.handle(
          _shareTemplateMeta,
          shareTemplate.isAcceptableOrUnknown(
              data['share_template']!, _shareTemplateMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {challengeDate};
  @override
  DailyChallengeCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyChallengeCache(
      challengeDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}challenge_date'])!,
      cardIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_ids'])!,
      shareTemplate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}share_template']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $DailyChallengeCachesTable createAlias(String alias) {
    return $DailyChallengeCachesTable(attachedDatabase, alias);
  }
}

class DailyChallengeCache extends DataClass
    implements Insertable<DailyChallengeCache> {
  final String challengeDate;
  final String cardIds;
  final String? shareTemplate;
  final int cachedAt;
  const DailyChallengeCache(
      {required this.challengeDate,
      required this.cardIds,
      this.shareTemplate,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['challenge_date'] = Variable<String>(challengeDate);
    map['card_ids'] = Variable<String>(cardIds);
    if (!nullToAbsent || shareTemplate != null) {
      map['share_template'] = Variable<String>(shareTemplate);
    }
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  DailyChallengeCachesCompanion toCompanion(bool nullToAbsent) {
    return DailyChallengeCachesCompanion(
      challengeDate: Value(challengeDate),
      cardIds: Value(cardIds),
      shareTemplate: shareTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(shareTemplate),
      cachedAt: Value(cachedAt),
    );
  }

  factory DailyChallengeCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyChallengeCache(
      challengeDate: serializer.fromJson<String>(json['challengeDate']),
      cardIds: serializer.fromJson<String>(json['cardIds']),
      shareTemplate: serializer.fromJson<String?>(json['shareTemplate']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'challengeDate': serializer.toJson<String>(challengeDate),
      'cardIds': serializer.toJson<String>(cardIds),
      'shareTemplate': serializer.toJson<String?>(shareTemplate),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  DailyChallengeCache copyWith(
          {String? challengeDate,
          String? cardIds,
          Value<String?> shareTemplate = const Value.absent(),
          int? cachedAt}) =>
      DailyChallengeCache(
        challengeDate: challengeDate ?? this.challengeDate,
        cardIds: cardIds ?? this.cardIds,
        shareTemplate:
            shareTemplate.present ? shareTemplate.value : this.shareTemplate,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  DailyChallengeCache copyWithCompanion(DailyChallengeCachesCompanion data) {
    return DailyChallengeCache(
      challengeDate: data.challengeDate.present
          ? data.challengeDate.value
          : this.challengeDate,
      cardIds: data.cardIds.present ? data.cardIds.value : this.cardIds,
      shareTemplate: data.shareTemplate.present
          ? data.shareTemplate.value
          : this.shareTemplate,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyChallengeCache(')
          ..write('challengeDate: $challengeDate, ')
          ..write('cardIds: $cardIds, ')
          ..write('shareTemplate: $shareTemplate, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(challengeDate, cardIds, shareTemplate, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyChallengeCache &&
          other.challengeDate == this.challengeDate &&
          other.cardIds == this.cardIds &&
          other.shareTemplate == this.shareTemplate &&
          other.cachedAt == this.cachedAt);
}

class DailyChallengeCachesCompanion
    extends UpdateCompanion<DailyChallengeCache> {
  final Value<String> challengeDate;
  final Value<String> cardIds;
  final Value<String?> shareTemplate;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const DailyChallengeCachesCompanion({
    this.challengeDate = const Value.absent(),
    this.cardIds = const Value.absent(),
    this.shareTemplate = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyChallengeCachesCompanion.insert({
    required String challengeDate,
    required String cardIds,
    this.shareTemplate = const Value.absent(),
    required int cachedAt,
    this.rowid = const Value.absent(),
  })  : challengeDate = Value(challengeDate),
        cardIds = Value(cardIds),
        cachedAt = Value(cachedAt);
  static Insertable<DailyChallengeCache> custom({
    Expression<String>? challengeDate,
    Expression<String>? cardIds,
    Expression<String>? shareTemplate,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (challengeDate != null) 'challenge_date': challengeDate,
      if (cardIds != null) 'card_ids': cardIds,
      if (shareTemplate != null) 'share_template': shareTemplate,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyChallengeCachesCompanion copyWith(
      {Value<String>? challengeDate,
      Value<String>? cardIds,
      Value<String?>? shareTemplate,
      Value<int>? cachedAt,
      Value<int>? rowid}) {
    return DailyChallengeCachesCompanion(
      challengeDate: challengeDate ?? this.challengeDate,
      cardIds: cardIds ?? this.cardIds,
      shareTemplate: shareTemplate ?? this.shareTemplate,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (challengeDate.present) {
      map['challenge_date'] = Variable<String>(challengeDate.value);
    }
    if (cardIds.present) {
      map['card_ids'] = Variable<String>(cardIds.value);
    }
    if (shareTemplate.present) {
      map['share_template'] = Variable<String>(shareTemplate.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyChallengeCachesCompanion(')
          ..write('challengeDate: $challengeDate, ')
          ..write('cardIds: $cardIds, ')
          ..write('shareTemplate: $shareTemplate, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(Insertable<SyncMetaData> instance,
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
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String key;
  final String userId;
  final String value;
  const SyncMetaData(
      {required this.key, required this.userId, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['user_id'] = Variable<String>(userId);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      key: Value(key),
      userId: Value(userId),
      value: Value(value),
    );
  }

  factory SyncMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
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

  SyncMetaData copyWith({String? key, String? userId, String? value}) =>
      SyncMetaData(
        key: key ?? this.key,
        userId: userId ?? this.userId,
        value: value ?? this.value,
      );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      key: data.key.present ? data.key.value : this.key,
      userId: data.userId.present ? data.userId.value : this.userId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
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
      (other is SyncMetaData &&
          other.key == this.key &&
          other.userId == this.userId &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> key;
  final Value<String> userId;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.userId = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    this.userId = const Value.absent(),
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SyncMetaData> custom({
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

  SyncMetaCompanion copyWith(
      {Value<String>? key,
      Value<String>? userId,
      Value<String>? value,
      Value<int>? rowid}) {
    return SyncMetaCompanion(
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
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('userId: $userId, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
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
  late final $DailyChallengeCachesTable dailyChallengeCaches =
      $DailyChallengeCachesTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final CardsDao cardsDao = CardsDao(this as AppDatabase);
  late final ReviewsDao reviewsDao = ReviewsDao(this as AppDatabase);
  late final DecksDao decksDao = DecksDao(this as AppDatabase);
  late final GovernmentDao governmentDao = GovernmentDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final MetaDao metaDao = MetaDao(this as AppDatabase);
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
        dailyChallengeCaches,
        syncMeta
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
typedef $$DailyChallengeCachesTableCreateCompanionBuilder
    = DailyChallengeCachesCompanion Function({
  required String challengeDate,
  required String cardIds,
  Value<String?> shareTemplate,
  required int cachedAt,
  Value<int> rowid,
});
typedef $$DailyChallengeCachesTableUpdateCompanionBuilder
    = DailyChallengeCachesCompanion Function({
  Value<String> challengeDate,
  Value<String> cardIds,
  Value<String?> shareTemplate,
  Value<int> cachedAt,
  Value<int> rowid,
});

class $$DailyChallengeCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DailyChallengeCachesTable> {
  $$DailyChallengeCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get challengeDate => $composableBuilder(
      column: $table.challengeDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardIds => $composableBuilder(
      column: $table.cardIds, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shareTemplate => $composableBuilder(
      column: $table.shareTemplate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$DailyChallengeCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyChallengeCachesTable> {
  $$DailyChallengeCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get challengeDate => $composableBuilder(
      column: $table.challengeDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardIds => $composableBuilder(
      column: $table.cardIds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shareTemplate => $composableBuilder(
      column: $table.shareTemplate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$DailyChallengeCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyChallengeCachesTable> {
  $$DailyChallengeCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get challengeDate => $composableBuilder(
      column: $table.challengeDate, builder: (column) => column);

  GeneratedColumn<String> get cardIds =>
      $composableBuilder(column: $table.cardIds, builder: (column) => column);

  GeneratedColumn<String> get shareTemplate => $composableBuilder(
      column: $table.shareTemplate, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$DailyChallengeCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyChallengeCachesTable,
    DailyChallengeCache,
    $$DailyChallengeCachesTableFilterComposer,
    $$DailyChallengeCachesTableOrderingComposer,
    $$DailyChallengeCachesTableAnnotationComposer,
    $$DailyChallengeCachesTableCreateCompanionBuilder,
    $$DailyChallengeCachesTableUpdateCompanionBuilder,
    (
      DailyChallengeCache,
      BaseReferences<_$AppDatabase, $DailyChallengeCachesTable,
          DailyChallengeCache>
    ),
    DailyChallengeCache,
    PrefetchHooks Function()> {
  $$DailyChallengeCachesTableTableManager(
      _$AppDatabase db, $DailyChallengeCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyChallengeCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyChallengeCachesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyChallengeCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> challengeDate = const Value.absent(),
            Value<String> cardIds = const Value.absent(),
            Value<String?> shareTemplate = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyChallengeCachesCompanion(
            challengeDate: challengeDate,
            cardIds: cardIds,
            shareTemplate: shareTemplate,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String challengeDate,
            required String cardIds,
            Value<String?> shareTemplate = const Value.absent(),
            required int cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyChallengeCachesCompanion.insert(
            challengeDate: challengeDate,
            cardIds: cardIds,
            shareTemplate: shareTemplate,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailyChallengeCachesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $DailyChallengeCachesTable,
        DailyChallengeCache,
        $$DailyChallengeCachesTableFilterComposer,
        $$DailyChallengeCachesTableOrderingComposer,
        $$DailyChallengeCachesTableAnnotationComposer,
        $$DailyChallengeCachesTableCreateCompanionBuilder,
        $$DailyChallengeCachesTableUpdateCompanionBuilder,
        (
          DailyChallengeCache,
          BaseReferences<_$AppDatabase, $DailyChallengeCachesTable,
              DailyChallengeCache>
        ),
        DailyChallengeCache,
        PrefetchHooks Function()>;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  Value<String> userId,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> userId,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
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

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
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

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
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

class $$SyncMetaTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncMetaTable,
    SyncMetaData,
    $$SyncMetaTableFilterComposer,
    $$SyncMetaTableOrderingComposer,
    $$SyncMetaTableAnnotationComposer,
    $$SyncMetaTableCreateCompanionBuilder,
    $$SyncMetaTableUpdateCompanionBuilder,
    (SyncMetaData, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>),
    SyncMetaData,
    PrefetchHooks Function()> {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncMetaCompanion(
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
              SyncMetaCompanion.insert(
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

typedef $$SyncMetaTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncMetaTable,
    SyncMetaData,
    $$SyncMetaTableFilterComposer,
    $$SyncMetaTableOrderingComposer,
    $$SyncMetaTableAnnotationComposer,
    $$SyncMetaTableCreateCompanionBuilder,
    $$SyncMetaTableUpdateCompanionBuilder,
    (SyncMetaData, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>),
    SyncMetaData,
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
  $$DailyChallengeCachesTableTableManager get dailyChallengeCaches =>
      $$DailyChallengeCachesTableTableManager(_db, _db.dailyChallengeCaches);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
