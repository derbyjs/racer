
export class FastMap<T>{
  values: Record<string, T>;
  size: number;

  constructor() {
    this.values = {};
    this.size = 0;
  }

  set(key: string, value: T) {
    if (!(key in this.values)) {
      this.size++;
    }
    return this.values[key] = value;
  };

  del(key: string) {
    if (key in this.values) {
      this.size--;
    }
    delete this.values[key];
  };
}
