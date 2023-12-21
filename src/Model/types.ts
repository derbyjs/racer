
  // | { ref: any };
/**
 * 
  export type Path = string | number;
  export type PathSegment = string | number;
  export type PathLike = Path | Model<any>;
 */


// could be 
// ['foo', 3, 'bar']
// always converted to string internally
export type Segment = string;

// PathLike
export type Segments = Array<Segment>;
