// Hardcoded mirror of content/governments/us/government.yaml.
// Replaced by the YAML-loaded content pipeline in a later phase.

class GovNodeSeed {
  const GovNodeSeed({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.nodeType,
    required this.tierOrder,
    required this.unlockRequires,
    required this.mapX,
    required this.mapY,
    required this.mapWidth,
    required this.mapHeight,
    required this.mapShape,
    required this.mapColor,
    this.isHeadOfState = false,
    this.isHeadOfGovt = false,
    this.isElected,
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final String nodeType;
  final int tierOrder;
  final List<String> unlockRequires;
  final double mapX;
  final double mapY;
  final double mapWidth;
  final double mapHeight;
  final String mapShape;
  final String mapColor;
  final bool isHeadOfState;
  final bool isHeadOfGovt;
  final bool? isElected;
}

class GovEdgeSeed {
  const GovEdgeSeed({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.relationshipType,
    required this.lineStyle,
    required this.lineColor,
    required this.isVisibleOnMap,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String relationshipType;
  final String lineStyle;
  final String lineColor;
  final bool isVisibleOnMap;
}

const usGovernmentId = 'us-government';

const usGovNodes = <GovNodeSeed>[
  GovNodeSeed(
    id: 'us-node-president',
    name: 'The Presidency',
    shortName: 'President',
    description:
        'Head of state and head of government. Directly elected every four years. Commander-in-chief; signs or vetoes legislation; appoints Cabinet, judges, and Supreme Court justices (subject to Senate confirmation).',
    nodeType: 'executive',
    isHeadOfState: true,
    isHeadOfGovt: true,
    isElected: true,
    tierOrder: 1,
    unlockRequires: [],
    mapX: 0.50,
    mapY: 0.18,
    mapWidth: 0.22,
    mapHeight: 0.11,
    mapShape: 'rectangle',
    mapColor: '#8B0000',
  ),
  GovNodeSeed(
    id: 'us-node-cabinet',
    name: 'The Cabinet',
    shortName: 'Cabinet',
    description:
        '15 department secretaries who advise the President and lead major federal agencies. Appointed by the President, confirmed by the Senate. Includes the statutory line of succession to the Presidency.',
    nodeType: 'executive',
    isElected: false,
    tierOrder: 2,
    unlockRequires: ['us-node-president'],
    mapX: 0.50,
    mapY: 0.34,
    mapWidth: 0.20,
    mapHeight: 0.10,
    mapShape: 'rectangle',
    mapColor: '#A0001E',
  ),
  GovNodeSeed(
    id: 'us-node-exec-office',
    name: 'Executive Office of the President',
    shortName: 'EOP',
    description:
        'Agencies that directly support the President: Chief of Staff, National Security Advisor, Press Secretary, OMB, US Trade Representative.',
    nodeType: 'executive',
    isElected: false,
    tierOrder: 3,
    unlockRequires: ['us-node-president'],
    mapX: 0.75,
    mapY: 0.26,
    mapWidth: 0.18,
    mapHeight: 0.09,
    mapShape: 'rectangle',
    mapColor: '#B22222',
  ),
  GovNodeSeed(
    id: 'us-node-congress',
    name: 'Congress',
    shortName: 'Congress',
    description:
        'The bicameral federal legislature consisting of the Senate and the House of Representatives. Article I of the Constitution grants Congress all federal legislative powers.',
    nodeType: 'legislature',
    isElected: true,
    tierOrder: 2,
    unlockRequires: ['us-node-president'],
    mapX: 0.25,
    mapY: 0.34,
    mapWidth: 0.20,
    mapHeight: 0.10,
    mapShape: 'rectangle',
    mapColor: '#002868',
  ),
  GovNodeSeed(
    id: 'us-node-senate',
    name: 'United States Senate',
    shortName: 'Senate',
    description:
        '100 senators (two per state) serving six-year staggered terms. Confirms appointments, ratifies treaties (two-thirds majority), and serves as the jury in impeachment trials.',
    nodeType: 'legislature',
    isElected: true,
    tierOrder: 3,
    unlockRequires: ['us-node-congress'],
    mapX: 0.15,
    mapY: 0.52,
    mapWidth: 0.20,
    mapHeight: 0.10,
    mapShape: 'rectangle',
    mapColor: '#002868',
  ),
  GovNodeSeed(
    id: 'us-node-house',
    name: 'House of Representatives',
    shortName: 'House',
    description:
        '435 representatives apportioned by state population on two-year terms. Originates revenue bills, initiates impeachment, and elects the President if no Electoral College majority.',
    nodeType: 'legislature',
    isElected: true,
    tierOrder: 3,
    unlockRequires: ['us-node-congress'],
    mapX: 0.35,
    mapY: 0.52,
    mapWidth: 0.20,
    mapHeight: 0.10,
    mapShape: 'rectangle',
    mapColor: '#002868',
  ),
  GovNodeSeed(
    id: 'us-node-how-laws-are-made',
    name: 'How Laws Are Made',
    shortName: 'Legislation',
    description:
        'Introduction → committee → floor debate → other chamber → conference committee → Presidential signature or veto → veto override vote.',
    nodeType: 'legislature',
    isElected: false,
    tierOrder: 4,
    unlockRequires: ['us-node-senate', 'us-node-house'],
    mapX: 0.25,
    mapY: 0.67,
    mapWidth: 0.20,
    mapHeight: 0.09,
    mapShape: 'rectangle',
    mapColor: '#003580',
  ),
  GovNodeSeed(
    id: 'us-node-scotus',
    name: 'Supreme Court of the United States',
    shortName: 'SCOTUS',
    description:
        'Highest federal court and final interpreter of the Constitution. Nine justices appointed for life. Power of judicial review established by Marbury v. Madison (1803).',
    nodeType: 'judicial',
    isElected: false,
    tierOrder: 4,
    unlockRequires: ['us-node-senate'],
    mapX: 0.75,
    mapY: 0.55,
    mapWidth: 0.20,
    mapHeight: 0.10,
    mapShape: 'rectangle',
    mapColor: '#3d3d3d',
  ),
  GovNodeSeed(
    id: 'us-node-parties',
    name: 'Party Leadership and Opposition',
    shortName: 'Parties',
    description:
        'Political figures outside the current government: former Presidents, party chairs, leading opposition figures, significant candidates. Party structures are distinct from but intertwined with government structures.',
    nodeType: 'political-party',
    isElected: false,
    tierOrder: 6,
    unlockRequires: ['us-node-senate', 'us-node-house'],
    mapX: 0.12,
    mapY: 0.80,
    mapWidth: 0.20,
    mapHeight: 0.09,
    mapShape: 'rectangle',
    mapColor: '#5a5a8a',
  ),
];

const usGovEdges = <GovEdgeSeed>[
  GovEdgeSeed(
    id: 'us-edge-pres-cabinet',
    fromNodeId: 'us-node-president',
    toNodeId: 'us-node-cabinet',
    relationshipType: 'appoints',
    lineStyle: 'solid',
    lineColor: '#8B0000',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-pres-eop',
    fromNodeId: 'us-node-president',
    toNodeId: 'us-node-exec-office',
    relationshipType: 'commands',
    lineStyle: 'solid',
    lineColor: '#8B0000',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-pres-scotus',
    fromNodeId: 'us-node-president',
    toNodeId: 'us-node-scotus',
    relationshipType: 'nominates',
    lineStyle: 'solid',
    lineColor: '#8B0000',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-senate-scotus',
    fromNodeId: 'us-node-senate',
    toNodeId: 'us-node-scotus',
    relationshipType: 'confirms',
    lineStyle: 'dashed',
    lineColor: '#002868',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-senate-cabinet',
    fromNodeId: 'us-node-senate',
    toNodeId: 'us-node-cabinet',
    relationshipType: 'confirms',
    lineStyle: 'dashed',
    lineColor: '#002868',
    isVisibleOnMap: false,
  ),
  GovEdgeSeed(
    id: 'us-edge-scotus-pres',
    fromNodeId: 'us-node-scotus',
    toNodeId: 'us-node-president',
    relationshipType: 'checks',
    lineStyle: 'dotted',
    lineColor: '#4a4a4a',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-scotus-congress',
    fromNodeId: 'us-node-scotus',
    toNodeId: 'us-node-congress',
    relationshipType: 'checks',
    lineStyle: 'dotted',
    lineColor: '#4a4a4a',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-congress-pres',
    fromNodeId: 'us-node-congress',
    toNodeId: 'us-node-president',
    relationshipType: 'checks',
    lineStyle: 'dotted',
    lineColor: '#002868',
    isVisibleOnMap: true,
  ),
  GovEdgeSeed(
    id: 'us-edge-senate-congress',
    fromNodeId: 'us-node-senate',
    toNodeId: 'us-node-congress',
    relationshipType: 'is-part-of',
    lineStyle: 'solid',
    lineColor: '#002868',
    isVisibleOnMap: false,
  ),
  GovEdgeSeed(
    id: 'us-edge-house-congress',
    fromNodeId: 'us-node-house',
    toNodeId: 'us-node-congress',
    relationshipType: 'is-part-of',
    lineStyle: 'solid',
    lineColor: '#002868',
    isVisibleOnMap: false,
  ),
];
