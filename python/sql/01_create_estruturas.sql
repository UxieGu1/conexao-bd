-- ============================================================================
-- UNIVERSIDADE FEDERAL DO CEARÁ (UFC) - CAMPUS QUIXADÁ
-- DISCIPLINA: Fundamentos de Bancos de Dados (Etapa 2 - Projeto e Implementação)
-- PROJETO: Sistema de Acompanhamento de Obras Públicas (Equipe T01)
-- SCRIPT 01: Criação das estruturas do banco de dados, restrições e triggers
-- ============================================================================

DROP TABLE IF EXISTS apontamento_cidadao CASCADE;
DROP TABLE IF EXISTS documento_evidencia CASCADE;
DROP TABLE IF EXISTS atualizacao_execucao CASCADE;
DROP TABLE IF EXISTS aditivo_financeiro CASCADE;
DROP TABLE IF EXISTS fase_medicao CASCADE;
DROP TABLE IF EXISTS contrato CASCADE;
DROP TABLE IF EXISTS obra CASCADE;
DROP TABLE IF EXISTS empresa CASCADE;
DROP TABLE IF EXISTS licitacao CASCADE;
DROP TABLE IF EXISTS secretaria CASCADE;

-- 1. SECRETARIA (RF11)
CREATE TABLE secretaria (
    id_secretaria SERIAL PRIMARY KEY,
    nome_oficial VARCHAR(150) NOT NULL UNIQUE,
    sigla VARCHAR(20)
);

-- 2. LICITACAO (RF06, RN05)
CREATE TABLE licitacao (
    id_licitacao SERIAL PRIMARY KEY,
    numero_licitacao VARCHAR(50) NOT NULL UNIQUE,
    modalidade VARCHAR(60) NOT NULL,
    data_abertura DATE NOT NULL,
    situacao VARCHAR(40) NOT NULL CHECK (
        situacao IN ('aberta', 'em julgamento', 'homologada', 'deserta', 'cancelada')
    )
);

-- 3. EMPRESA (RF02, RN05)
CREATE TABLE empresa (
    id_empresa SERIAL PRIMARY KEY,
    razao_social VARCHAR(150) NOT NULL,
    cnpj VARCHAR(18) NOT NULL UNIQUE CHECK (
        char_length(regexp_replace(cnpj, '\D', '', 'g')) = 14
    ),
    telefone VARCHAR(20),
    email VARCHAR(120)
);

-- 4. OBRA (RF01, RF08, RF09, RF14, RN06, RN07, RN08)
CREATE TABLE obra (
    id_obra SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    local_execucao VARCHAR(255) NOT NULL,
    data_inicio DATE NOT NULL,
    data_prevista_conclusao DATE NOT NULL,
    orcamento_previsto NUMERIC(14, 2) NOT NULL CHECK (orcamento_previsto > 0),
    situacao VARCHAR(30) NOT NULL DEFAULT 'planejada' CHECK (
        situacao IN ('planejada', 'em andamento', 'suspensa', 'concluída', 'cancelada')
    ),
    id_secretaria INT NOT NULL REFERENCES secretaria(id_secretaria) ON DELETE RESTRICT,
    id_licitacao INT NULL REFERENCES licitacao(id_licitacao) ON DELETE SET NULL,
    CHECK (data_prevista_conclusao >= data_inicio)
);

-- 5. CONTRATO (RF07, RF15, RN02, RN05, RN06)
CREATE TABLE contrato (
    id_contrato SERIAL PRIMARY KEY,
    numero_contrato VARCHAR(50) NOT NULL UNIQUE,
    data_assinatura DATE NOT NULL,
    prazo_vigencia_dias INT NOT NULL CHECK (prazo_vigencia_dias > 0),
    valor_contratado NUMERIC(14, 2) NOT NULL CHECK (valor_contratado > 0),
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE,
    id_empresa INT NOT NULL REFERENCES empresa(id_empresa) ON DELETE RESTRICT
);

-- 6. FASE_MEDICAO (RF03, RN01, RN03, RN06, RN07)
CREATE TABLE fase_medicao (
    id_fase SERIAL PRIMARY KEY,
    nome_fase VARCHAR(120) NOT NULL,
    data_medicao DATE NOT NULL,
    percentual_conclusao NUMERIC(5, 2) NOT NULL CHECK (
        percentual_conclusao >= 0 AND percentual_conclusao <= 100
    ),
    peso_fase NUMERIC(5, 2) NOT NULL DEFAULT 100.00 CHECK (
        peso_fase > 0 AND peso_fase <= 100
    ),
    observacoes TEXT,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 7. ADITIVO_FINANCEIRO (RF04, RF15, RN04, RN06)
CREATE TABLE aditivo_financeiro (
    id_aditivo SERIAL PRIMARY KEY,
    valor_aditivo NUMERIC(14, 2) NOT NULL CHECK (valor_aditivo > 0),
    data_aditivo DATE NOT NULL DEFAULT CURRENT_DATE,
    justificativa TEXT NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 8. ATUALIZACAO_EXECUCAO (RF08, RF12, RF13, RF14, RN10)
CREATE TABLE atualizacao_execucao (
    id_atualizacao SERIAL PRIMARY KEY,
    data_referencia DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo_registro VARCHAR(30) NOT NULL CHECK (
        tipo_registro IN ('andamento', 'mudanca_situacao', 'alteracao_prazo')
    ),
    situacao_registrada VARCHAR(30) NULL CHECK (
        situacao_registrada IN ('planejada', 'em andamento', 'suspensa', 'concluída', 'cancelada')
    ),
    nova_data_prevista DATE NULL,
    descricao TEXT NOT NULL,
    responsavel_registro VARCHAR(120) NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 9. DOCUMENTO_EVIDENCIA (RF10, RN06)
CREATE TABLE documento_evidencia (
    id_documento SERIAL PRIMARY KEY,
    descricao VARCHAR(255) NOT NULL,
    data_documento DATE NOT NULL DEFAULT CURRENT_DATE,
    localizacao_arquivo VARCHAR(500) NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE,
    id_fase INT NULL REFERENCES fase_medicao(id_fase) ON DELETE SET NULL
);

-- 10. APONTAMENTO_CIDADAO (RF05, RN06, RN09)
CREATE TABLE apontamento_cidadao (
    id_apontamento SERIAL PRIMARY KEY,
    descricao TEXT NOT NULL,
    data_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    cpf_cidadao VARCHAR(14) NULL CHECK (
        cpf_cidadao IS NULL OR char_length(regexp_replace(cpf_cidadao, '\D', '', 'g')) = 11
    ),
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- ============================================================================
-- TRIGGERS DE REGRAS DE NEGÓCIO (RN04 e RN07)
-- ============================================================================

-- RN04: Aditivo financeiro só pode ser registrado para obra 'em andamento'
CREATE OR REPLACE FUNCTION fn_validar_aditivo_obra()
RETURNS TRIGGER AS $$
DECLARE
    v_situacao VARCHAR(30);
BEGIN
    SELECT situacao INTO v_situacao FROM obra WHERE id_obra = NEW.id_obra;
    IF v_situacao <> 'em andamento' THEN
        RAISE EXCEPTION 'RN04: Não é permitido registrar aditivo para obra com situação "%". A obra deve estar "em andamento".', v_situacao;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_aditivo_obra
BEFORE INSERT ON aditivo_financeiro
FOR EACH ROW EXECUTE FUNCTION fn_validar_aditivo_obra();

-- RN07: Obra 'concluída' não deve receber novas medições de execução
CREATE OR REPLACE FUNCTION fn_validar_medicao_obra_concluida()
RETURNS TRIGGER AS $$
DECLARE
    v_situacao VARCHAR(30);
BEGIN
    SELECT situacao INTO v_situacao FROM obra WHERE id_obra = NEW.id_obra;
    IF v_situacao = 'concluída' THEN
        RAISE EXCEPTION 'RN07: Obra já concluída não pode receber novas medições sem reabertura formal.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_medicao_obra_concluida
BEFORE INSERT ON fase_medicao
FOR EACH ROW EXECUTE FUNCTION fn_validar_medicao_obra_concluida();
