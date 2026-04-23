-- Run this once via scripts/setup_db.py or directly no Supabase SQL Editor

-- Tabela de páginas da wiki
create table if not exists wiki_pages (
    id          text primary key,
    path        text        not null,
    title       text        not null,
    content     text        not null,
    updated_at  timestamptz not null,
    synced_at   timestamptz not null default now(),
    url         text        not null,
    search_vec  tsvector
);

-- Índice GIN para full-text search
create index if not exists wiki_pages_search_idx
    on wiki_pages using gin(search_vec);

-- Trigger para atualizar search_vec automaticamente
create or replace function wiki_pages_search_update()
returns trigger language plpgsql as $$
begin
    new.search_vec :=
        setweight(to_tsvector('portuguese', coalesce(new.title, '')), 'A') ||
        setweight(to_tsvector('portuguese', coalesce(new.content, '')), 'B');
    return new;
end;
$$;

drop trigger if exists wiki_pages_search_trigger on wiki_pages;
create trigger wiki_pages_search_trigger
    before insert or update on wiki_pages
    for each row execute function wiki_pages_search_update();

-- Função de busca FTS (chamada via supabase.rpc)
create or replace function search_wiki_pages(
    query_text  text,
    result_limit int default 5
)
returns table (
    id          text,
    path        text,
    title       text,
    content     text,
    updated_at  timestamptz,
    url         text,
    rank        float4
)
language sql stable as $$
    select
        id, path, title,
        -- Trunca o content para não explodir o contexto do LLM
        left(content, 3000) as content,
        updated_at,
        url,
        ts_rank(search_vec, websearch_to_tsquery('portuguese', query_text)) as rank
    from wiki_pages
    where search_vec @@ websearch_to_tsquery('portuguese', query_text)
    order by rank desc
    limit result_limit;
$$;
