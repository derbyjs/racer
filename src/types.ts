import { Model } from "./Model";

//
// Simple and utility types
//
export type UUID = string;
export type Path = string | number;
export type PathSegment = string | number;
export type PathLike = Path | Model<any>;

export type Primitive = boolean | number | string | null | undefined;

/** If `T` is an array, produces the type of the array items. */
export type ArrayItemType<T> = T extends Array<infer U> ? U : never;

export type Callback = (error?: Error) => void;

/**
 * Transforms a JSON-compatible type `T` such that it and any nested arrays
 * or basic objects are read-only.
 *
 * Warnings:
 * * Instances of most classes could still be modified via methods, aside from
 *   built-in `Array`s, which are transformed to `ReadonlyArray`s with no
 *   mutator methods.
 * * This only affects static type-checking and is not a guarantee of run-time
 *   immutability. Values with this type could still be modified if casted
 *   to `any`, passed into a function with an `any` signature, or by untyped
 *   JavaScript.
 *
 * Use `deepCopy(value)` to get a fully mutable copy of a `ReadonlyDeep`.
 */
export type ReadonlyDeep<T> = T extends Primitive ? T : { readonly [K in keyof T]: ReadonlyDeep<T[K]> };

/**
 * Transforms a JSON-compatible type `T` such that top-level properties remain
 * mutable if they were before, but nested arrays or basic objects become
 * read-only.
 *
 * Warning: This does not fully guarantee immutability. See `ReadonlyDeep` for
 * more details.
 */
export type ShallowCopiedValue<T> = T extends Primitive ? T : { [K in keyof T]: ReadonlyDeep<T[K]> };

/**
 * Transforms the input JSON-compatible type `T` to be fully mutable, if it
 * isn't already.
 *
 * This should only be used for the return type of a deep-copy function. Do
 * not manually cast using this type otherwise.
 */
export type MutableDeep<T> = T extends ReadonlyDeep<Date>
  ? Date
  : T extends object
  ? { -readonly [K in keyof T]: MutableDeep<T[K]> }
  : T;

/**
 * Transforms the input JSON-compatible type `T` such that its top-level
 * properties are mutable, if they weren't already.
 *
 * This should only be used for the return type of a shallow-copy function. Do
 * not manually cast using this type otherwise.
 */
export type MutableShallow<T> = T extends ShallowCopiedValue<Date>
  ? Date
  : T extends object
  ? { -readonly [K in keyof T]: T[K] }
  : T;
