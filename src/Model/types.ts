
  // | { ref: any };
/**
 * 
  export type Path = string | number;
  export type PathSegment = string | number;
  export type PathLike = Path | Model<any>;
 */

import { Path } from "../types";


// could be 
// ['foo', 3, 'bar']
// always converted to string internally
export type Segment = Path;

// PathLike
export type Segments = Array<Segment>;
