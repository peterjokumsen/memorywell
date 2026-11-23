import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export type Entity =
  | 'households'
  | 'chronicles'
  | 'contributors'
  | 'invites'
  | 'prompts'
  | 'memories'
  | 'transcripts'
  | 'flags'
  | 'aliasHistory';

const ENTITIES: readonly Entity[] = [
  'households',
  'chronicles',
  'contributors',
  'invites',
  'prompts',
  'memories',
  'transcripts',
  'flags',
  'aliasHistory',
];

@Injectable({ providedIn: 'root' })
export class BffService {
  private http = inject(HttpClient);
  private base = environment.bffBaseUrl;

  private url(path: string): string {
    return `${this.base}${path}`;
  }

  list(entity: Entity, params?: Record<string, string>): Observable<any> {
    let httpParams = new HttpParams();
    if (params) {
      for (const [k, v] of Object.entries(params)) {
        httpParams = httpParams.set(k, v);
      }
    }
    return this.http.get(this.url(`/api/${entity}`), {
      params: httpParams,
      withCredentials: true,
    });
  }

  get(entity: Entity, id: string, params?: Record<string, string>): Observable<any> {
    let httpParams = new HttpParams();
    if (params) {
      for (const [k, v] of Object.entries(params)) {
        httpParams = httpParams.set(k, v);
      }
    }
    return this.http.get(this.url(`/api/${entity}/${id}`), {
      params: httpParams,
      withCredentials: true,
    });
  }

  create(entity: Entity, body: any): Observable<any> {
    return this.http.post(this.url(`/api/${entity}`), body, { withCredentials: true });
  }

  update(entity: Entity, id: string, body: any): Observable<any> {
    return this.http.put(this.url(`/api/${entity}/${id}`), body, { withCredentials: true });
  }

  patch(entity: Entity, id: string, body: any): Observable<any> {
    return this.http.patch(this.url(`/api/${entity}/${id}`), body, { withCredentials: true });
  }

  delete(entity: Entity, id: string): Observable<any> {
    return this.http.delete(this.url(`/api/${entity}/${id}`), { withCredentials: true });
  }

  openApi(): Observable<any> {
    return this.http.get(this.url('/api/openapi.json'), { withCredentials: true });
  }
}

export { ENTITIES };
